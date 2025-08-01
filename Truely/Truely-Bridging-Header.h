//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#include <sys/sysctl.h>
#include <libproc.h>
#include <sys/proc_info.h>
#include <unistd.h>
#include <string.h>
#include <pthread.h>

#import "ProcessBridge.h"

// Additional Swift-compatible error handling helpers
static inline int isBridgeSuccess(int result) {
    return result == BRIDGE_SUCCESS;
}

static inline int isBridgeError(int result) {
    return result < 0;
}

static inline const char* getBridgeErrorDescription(int errorCode) {
    switch (errorCode) {
        case BRIDGE_SUCCESS:
            return "Success";
        case BRIDGE_ERROR_NULL_POINTER:
            return "Null pointer error";
        case BRIDGE_ERROR_INVALID_PARAMETER:
            return "Invalid parameter";
        case BRIDGE_ERROR_MEMORY_ALLOCATION:
            return "Memory allocation failed";
        case BRIDGE_ERROR_SYSTEM_CALL:
            return "System call failed";
        case BRIDGE_ERROR_FILE_ACCESS:
            return "File access error";
        default:
            return "Unknown error";
    }
}