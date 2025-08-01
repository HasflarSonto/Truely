#include "ProcessBridge.h"

// Global mutex for thread safety
static pthread_mutex_t g_bridge_mutex = PTHREAD_MUTEX_INITIALIZER;
static int g_bridge_initialized = 0;

// Thread safety functions
int initializeProcessBridge(void) {
    int result = pthread_mutex_lock(&g_bridge_mutex);
    if (result != 0) {
        return BRIDGE_ERROR_SYSTEM_CALL;
    }
    
    if (!g_bridge_initialized) {
        g_bridge_initialized = 1;
    }
    
    pthread_mutex_unlock(&g_bridge_mutex);
    return BRIDGE_SUCCESS;
}

void cleanupProcessBridge(void) {
    pthread_mutex_lock(&g_bridge_mutex);
    g_bridge_initialized = 0;
    pthread_mutex_unlock(&g_bridge_mutex);
    pthread_mutex_destroy(&g_bridge_mutex);
}

int getAllProcesses(SystemProcessInfo **processes) {
    if (!processes) {
        return BRIDGE_ERROR_NULL_POINTER;
    }
    
    // Ensure thread safety for this critical operation
    int mutex_result = pthread_mutex_lock(&g_bridge_mutex);
    if (mutex_result != 0) {
        return BRIDGE_ERROR_SYSTEM_CALL;
    }
    
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t size;
    
    // Get the size needed
    if (sysctl(mib, 4, NULL, &size, NULL, 0) != 0) {
        pthread_mutex_unlock(&g_bridge_mutex);
        return BRIDGE_ERROR_SYSTEM_CALL;
    }
    
    if (size == 0) {
        pthread_mutex_unlock(&g_bridge_mutex);
        return BRIDGE_ERROR_INVALID_PARAMETER;
    }
    
    // Allocate memory for process list
    struct kinfo_proc *proc_list = malloc(size);
    if (!proc_list) {
        pthread_mutex_unlock(&g_bridge_mutex);
        return BRIDGE_ERROR_MEMORY_ALLOCATION;
    }
    
    // Get the actual process list
    if (sysctl(mib, 4, proc_list, &size, NULL, 0) != 0) {
        free(proc_list);
        pthread_mutex_unlock(&g_bridge_mutex);
        return BRIDGE_ERROR_SYSTEM_CALL;
    }
    
    int proc_count = (int)(size / sizeof(struct kinfo_proc));
    if (proc_count <= 0) {
        free(proc_list);
        pthread_mutex_unlock(&g_bridge_mutex);
        return BRIDGE_ERROR_INVALID_PARAMETER;
    }
    
    // Allocate our SystemProcessInfo array
    *processes = malloc(proc_count * sizeof(SystemProcessInfo));
    if (!*processes) {
        free(proc_list);
        pthread_mutex_unlock(&g_bridge_mutex);
        return BRIDGE_ERROR_MEMORY_ALLOCATION;
    }
    
    int valid_count = 0;
    
    for (int i = 0; i < proc_count; i++) {
        pid_t pid = proc_list[i].kp_proc.p_pid;
        
        // Skip kernel processes (PID 0)
        if (pid <= 0) continue;
        
        SystemProcessInfo *info = &(*processes)[valid_count];
        info->pid = pid;
        
        // Initialize all fields to safe defaults
        memset(info->name, 0, sizeof(info->name));
        memset(info->path, 0, sizeof(info->path));
        info->windowCount = 0;
        info->screenEvasionCount = 0;
        info->elevatedLayerCount = 0;
        info->suspiciousWindowCount = 0;
        
        // Get process name
        if (getProcessName(pid, info->name, sizeof(info->name)) == BRIDGE_SUCCESS) {
            // Get process path (non-critical if it fails)
            getProcessPath(pid, info->path, sizeof(info->path));
            
            // Get window information (non-critical if they fail)
            info->windowCount = getWindowCount(pid);
            info->screenEvasionCount = detectScreenEvasion(pid);
            info->elevatedLayerCount = detectElevatedLayers(pid);
            info->suspiciousWindowCount = (info->screenEvasionCount > 0 || info->elevatedLayerCount > 0) ? 1 : 0;
            
            valid_count++;
        }
    }
    
    free(proc_list);
    pthread_mutex_unlock(&g_bridge_mutex);
    return valid_count;
}

int getProcessName(pid_t pid, char *name, size_t nameSize) {
    if (!name || nameSize == 0) {
        return BRIDGE_ERROR_NULL_POINTER;
    }
    
    if (pid <= 0) {
        return BRIDGE_ERROR_INVALID_PARAMETER;
    }
    
    struct proc_bsdinfo proc_info;
    
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &proc_info, sizeof(proc_info)) <= 0) {
        return BRIDGE_ERROR_SYSTEM_CALL;
    }
    
    strncpy(name, proc_info.pbi_name, nameSize - 1);
    name[nameSize - 1] = '\0';
    return BRIDGE_SUCCESS;
}

int getProcessPath(pid_t pid, char *path, size_t pathSize) {
    if (!path || pathSize == 0) {
        return BRIDGE_ERROR_NULL_POINTER;
    }
    
    if (pid <= 0) {
        return BRIDGE_ERROR_INVALID_PARAMETER;
    }
    
    // Ensure pathSize fits in uint32_t for proc_pidpath
    if (pathSize > UINT32_MAX) {
        return BRIDGE_ERROR_INVALID_PARAMETER;
    }
    
    if (proc_pidpath(pid, path, (uint32_t)pathSize) <= 0) {
        path[0] = '\0';
        return BRIDGE_ERROR_SYSTEM_CALL;
    }
    return BRIDGE_SUCCESS;
}

void freeProcessList(SystemProcessInfo *processes) {
    if (processes) {
        free(processes);
    }
}

int calculateFileSHA256(const char *filePath, char *hashString, size_t hashStringSize) {
    if (!filePath || !hashString) {
        return BRIDGE_ERROR_NULL_POINTER;
    }
    
    if (hashStringSize < 65) {
        return BRIDGE_ERROR_INVALID_PARAMETER; // Need at least 65 bytes for SHA256 hex string + null terminator
    }
    
    if (strlen(filePath) == 0) {
        return BRIDGE_ERROR_INVALID_PARAMETER;
    }
    
    FILE *file = fopen(filePath, "rb");
    if (!file) {
        return BRIDGE_ERROR_FILE_ACCESS;
    }
    
    // Check if file is readable and get size for validation
    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        return BRIDGE_ERROR_FILE_ACCESS;
    }
    
    long fileSize = ftell(file);
    if (fileSize < 0) {
        fclose(file);
        return BRIDGE_ERROR_FILE_ACCESS;
    }
    
    if (fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return BRIDGE_ERROR_FILE_ACCESS;
    }
    
    CC_SHA256_CTX sha256Context;
    if (CC_SHA256_Init(&sha256Context) == 0) {
        fclose(file);
        return BRIDGE_ERROR_SYSTEM_CALL;
    }
    
    const size_t bufferSize = 4096;
    unsigned char buffer[bufferSize];
    size_t bytesRead;
    
    while ((bytesRead = fread(buffer, 1, bufferSize, file)) > 0) {
        // Ensure bytesRead fits in CC_LONG (uint32_t) to avoid truncation
        if (bytesRead > UINT32_MAX) {
            fclose(file);
            return BRIDGE_ERROR_INVALID_PARAMETER;
        }
        
        if (CC_SHA256_Update(&sha256Context, buffer, (CC_LONG)bytesRead) == 0) {
            fclose(file);
            return BRIDGE_ERROR_SYSTEM_CALL;
        }
    }
    
    // Check for read errors
    if (ferror(file)) {
        fclose(file);
        return BRIDGE_ERROR_FILE_ACCESS;
    }
    
    fclose(file);
    
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    if (CC_SHA256_Final(hash, &sha256Context) == 0) {
        return BRIDGE_ERROR_SYSTEM_CALL;
    }
    
    // Convert hash to hex string with bounds checking
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        int written = snprintf(hashString + (i * 2), 3, "%02x", hash[i]);
        if (written != 2) {
            return BRIDGE_ERROR_SYSTEM_CALL;
        }
    }
    hashString[CC_SHA256_DIGEST_LENGTH * 2] = '\0';
    
    return BRIDGE_SUCCESS;
}

// MARK: - Window Property Detection Functions

int getWindowCount(pid_t pid) {
    if (pid <= 0) {
        return 0;
    }
    
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    if (!windowList) {
        return 0;
    }
    
    int count = 0;
    CFIndex windowCount = CFArrayGetCount(windowList);
    
    for (CFIndex i = 0; i < windowCount; i++) {
        CFDictionaryRef window = (CFDictionaryRef)CFArrayGetValueAtIndex(windowList, i);
        
        CFNumberRef windowPID = (CFNumberRef)CFDictionaryGetValue(window, kCGWindowOwnerPID);
        if (windowPID) {
            int windowOwnerPID;
            CFNumberGetValue(windowPID, kCFNumberIntType, &windowOwnerPID);
            
            if (windowOwnerPID == pid) {
                count++;
            }
        }
    }
    
    CFRelease(windowList);
    return count;
}

int detectScreenEvasion(pid_t pid) {
    if (pid <= 0) {
        return 0;
    }
    
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionAll, kCGNullWindowID);
    if (!windowList) {
        return 0;
    }
    
    int suspiciousCount = 0;
    CFIndex windowCount = CFArrayGetCount(windowList);
    
    for (CFIndex i = 0; i < windowCount; i++) {
        CFDictionaryRef window = (CFDictionaryRef)CFArrayGetValueAtIndex(windowList, i);
        
        CFNumberRef windowPID = (CFNumberRef)CFDictionaryGetValue(window, kCGWindowOwnerPID);
        if (windowPID) {
            int windowOwnerPID;
            CFNumberGetValue(windowPID, kCFNumberIntType, &windowOwnerPID);
            
            if (windowOwnerPID == pid) {
                // Check for suspicious window properties
                CFDictionaryRef bounds = (CFDictionaryRef)CFDictionaryGetValue(window, kCGWindowBounds);
                if (bounds) {
                    CGRect rect;
                    CGRectMakeWithDictionaryRepresentation(bounds, &rect);
                    
                    // Detect windows that are suspiciously positioned (off-screen or very small)
                    if (rect.origin.x < -1000 || rect.origin.y < -1000 || 
                        rect.size.width < 1 || rect.size.height < 1 ||
                        rect.origin.x > 10000 || rect.origin.y > 10000) {
                        suspiciousCount++;
                    }
                }
                
                // Check for windows with suspicious sharing state
                CFNumberRef sharingState = (CFNumberRef)CFDictionaryGetValue(window, kCGWindowSharingState);
                if (sharingState) {
                    int sharing;
                    CFNumberGetValue(sharingState, kCFNumberIntType, &sharing);
                    
                    // kCGWindowSharingNone = 0 (window not available for reading)
                    if (sharing == 0) {
                        suspiciousCount++;
                    }
                }
            }
        }
    }
    
    CFRelease(windowList);
    return suspiciousCount;
}

int detectElevatedLayers(pid_t pid) {
    if (pid <= 0) {
        return 0;
    }
    
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionAll, kCGNullWindowID);
    if (!windowList) {
        return 0;
    }
    
    int elevatedCount = 0;
    CFIndex windowCount = CFArrayGetCount(windowList);
    
    for (CFIndex i = 0; i < windowCount; i++) {
        CFDictionaryRef window = (CFDictionaryRef)CFArrayGetValueAtIndex(windowList, i);
        
        CFNumberRef windowPID = (CFNumberRef)CFDictionaryGetValue(window, kCGWindowOwnerPID);
        if (windowPID) {
            int windowOwnerPID;
            CFNumberGetValue(windowPID, kCFNumberIntType, &windowOwnerPID);
            
            if (windowOwnerPID == pid) {
                // Check window layer
                CFNumberRef layer = (CFNumberRef)CFDictionaryGetValue(window, kCGWindowLayer);
                if (layer) {
                    int layerValue;
                    CFNumberGetValue(layer, kCFNumberIntType, &layerValue);
                    
                    // Elevated layers (above normal application windows)
                    // kCGFloatingWindowLevel = 3, kCGModalPanelWindowLevel = 8, etc.
                    if (layerValue > 2) {
                        elevatedCount++;
                    }
                }
            }
        }
    }
    
    CFRelease(windowList);
    return elevatedCount;
}

int getWindowProperties(pid_t pid, WindowProperties *properties) {
    if (!properties) {
        return BRIDGE_ERROR_NULL_POINTER;
    }
    
    if (pid <= 0) {
        return BRIDGE_ERROR_INVALID_PARAMETER;
    }
    
    properties->windowCount = getWindowCount(pid);
    properties->elevatedLayers = detectElevatedLayers(pid);
    properties->suspiciousPatterns = detectScreenEvasion(pid);
    properties->sharingStateDisabled = 0; // Will be set based on screen evasion results
    
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionAll, kCGNullWindowID);
    if (!windowList) {
        return BRIDGE_ERROR_SYSTEM_CALL;
    }
    
    CFIndex windowCount = CFArrayGetCount(windowList);
    
    for (CFIndex i = 0; i < windowCount; i++) {
        CFDictionaryRef window = (CFDictionaryRef)CFArrayGetValueAtIndex(windowList, i);
        
        CFNumberRef windowPID = (CFNumberRef)CFDictionaryGetValue(window, kCGWindowOwnerPID);
        if (windowPID) {
            int windowOwnerPID;
            CFNumberGetValue(windowPID, kCFNumberIntType, &windowOwnerPID);
            
            if (windowOwnerPID == pid) {
                CFNumberRef sharingState = (CFNumberRef)CFDictionaryGetValue(window, kCGWindowSharingState);
                if (sharingState) {
                    int sharing;
                    CFNumberGetValue(sharingState, kCFNumberIntType, &sharing);
                    
                    if (sharing == 0) {
                        properties->sharingStateDisabled++;
                    }
                }
            }
        }
    }
    
    CFRelease(windowList);
    return BRIDGE_SUCCESS;
}