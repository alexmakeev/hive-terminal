/*
 * MOSH FFI Stub Implementation
 *
 * This is a minimal stub for platforms where mosh libraries
 * are not available. All functions return appropriate error codes.
 */

#include "mosh_ffi.h"
#include <stdlib.h>

FFI_PLUGIN_EXPORT MoshResult mosh_init(void) {
    return MOSH_OK;
}

FFI_PLUGIN_EXPORT void mosh_cleanup(void) {
}

FFI_PLUGIN_EXPORT MoshSession mosh_session_create(
    const char* host,
    const char* port,
    const char* key,
    int width,
    int height
) {
    (void)host; (void)port; (void)key; (void)width; (void)height;
    return NULL; // Not supported
}

FFI_PLUGIN_EXPORT void mosh_session_set_callbacks(
    MoshSession session,
    MoshScreenCallback screen_cb,
    MoshErrorCallback error_cb,
    MoshStateCallback state_cb,
    void* user_data
) {
    (void)session; (void)screen_cb; (void)error_cb; (void)state_cb; (void)user_data;
}

FFI_PLUGIN_EXPORT MoshResult mosh_session_connect(MoshSession session) {
    (void)session;
    return MOSH_ERROR_NOT_CONNECTED;
}

FFI_PLUGIN_EXPORT MoshResult mosh_session_write(
    MoshSession session,
    const char* data,
    size_t len
) {
    (void)session; (void)data; (void)len;
    return MOSH_ERROR_NOT_CONNECTED;
}

FFI_PLUGIN_EXPORT MoshResult mosh_session_resize(
    MoshSession session,
    int width,
    int height
) {
    (void)session; (void)width; (void)height;
    return MOSH_ERROR_NOT_CONNECTED;
}

FFI_PLUGIN_EXPORT MoshResult mosh_session_poll(
    MoshSession session,
    int timeout_ms
) {
    (void)session; (void)timeout_ms;
    return MOSH_ERROR_NOT_CONNECTED;
}

FFI_PLUGIN_EXPORT MoshState mosh_session_get_state(MoshSession session) {
    (void)session;
    return MOSH_STATE_DISCONNECTED;
}

FFI_PLUGIN_EXPORT const char* mosh_session_get_error(MoshSession session) {
    (void)session;
    return "MOSH not available on this platform";
}

FFI_PLUGIN_EXPORT void mosh_session_destroy(MoshSession session) {
    (void)session;
}

FFI_PLUGIN_EXPORT const char* mosh_version(void) {
    return "mosh-ffi 0.1.0 (stub - mosh not available)";
}
