#ifndef ProcessBridge_h
#define ProcessBridge_h

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/sysctl.h>
#include <libproc.h>
#include <sys/proc_info.h>
#include <unistd.h>
#include <string.h>
#include <CommonCrypto/CommonDigest.h>
#include <CoreGraphics/CoreGraphics.h>
#include <ApplicationServices/ApplicationServices.h>
#include <pthread.h>

typedef enum {
    BRIDGE_SUCCESS = 0,
    BRIDGE_ERROR_NULL_POINTER = -1,
    BRIDGE_ERROR_INVALID_PARAMETER = -2,
    BRIDGE_ERROR_MEMORY_ALLOCATION = -3,
    BRIDGE_ERROR_SYSTEM_CALL = -4,
    BRIDGE_ERROR_FILE_ACCESS = -5
} BridgeErrorCode;

typedef struct {
    pid_t pid;
    char name[PROC_PIDPATHINFO_MAXSIZE];
    char path[PROC_PIDPATHINFO_MAXSIZE];
    int windowCount;
    int suspiciousWindowCount;
    int screenEvasionCount;
    int elevatedLayerCount;
} SystemProcessInfo;

typedef struct {
    int windowCount;
    int sharingStateDisabled;
    int elevatedLayers;
    int suspiciousPatterns;
} WindowProperties;

// Function declarations
int getAllProcesses(SystemProcessInfo **processes);
void freeProcessList(SystemProcessInfo *processes);
int getProcessName(pid_t pid, char *name, size_t nameSize);
int getProcessPath(pid_t pid, char *path, size_t pathSize);
int calculateFileSHA256(const char *filePath, char *hashString, size_t hashStringSize);

// Thread safety functions
int initializeProcessBridge(void);
void cleanupProcessBridge(void);

// Window property detection functions
int getWindowProperties(pid_t pid, WindowProperties *properties);
int detectScreenEvasion(pid_t pid);
int detectElevatedLayers(pid_t pid);
int getWindowCount(pid_t pid);

#endif /* ProcessBridge_h */
