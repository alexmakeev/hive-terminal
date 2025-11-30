/*
 * MOSH FFI Wrapper for Flutter
 *
 * This provides a C API wrapper around the mosh client library
 * for use with Dart FFI.
 */

#ifndef MOSH_FFI_H
#define MOSH_FFI_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default")))
#endif

/* Session handle - opaque pointer */
typedef void* MoshSession;

/* Session state */
typedef enum {
    MOSH_STATE_DISCONNECTED = 0,
    MOSH_STATE_CONNECTING = 1,
    MOSH_STATE_CONNECTED = 2,
    MOSH_STATE_ERROR = 3
} MoshState;

/* Result codes */
typedef enum {
    MOSH_OK = 0,
    MOSH_ERROR_INVALID_PARAMS = -1,
    MOSH_ERROR_CONNECT_FAILED = -2,
    MOSH_ERROR_NOT_CONNECTED = -3,
    MOSH_ERROR_CRYPTO = -4,
    MOSH_ERROR_NETWORK = -5,
    MOSH_ERROR_MEMORY = -6
} MoshResult;

/* Screen cell - single character with attributes */
typedef struct {
    uint32_t codepoint;
    uint32_t foreground;
    uint32_t background;
    uint8_t bold;
    uint8_t underline;
    uint8_t blink;
    uint8_t inverse;
} MoshCell;

/* Screen update callback */
typedef void (*MoshScreenCallback)(
    const MoshCell* cells,
    int width,
    int height,
    int cursor_x,
    int cursor_y,
    void* user_data
);

/* Error callback */
typedef void (*MoshErrorCallback)(
    const char* message,
    void* user_data
);

/* State change callback */
typedef void (*MoshStateCallback)(
    MoshState state,
    void* user_data
);

/*
 * Initialize the mosh library.
 * Must be called before any other functions.
 * Returns MOSH_OK on success.
 */
FFI_PLUGIN_EXPORT MoshResult mosh_init(void);

/*
 * Cleanup the mosh library.
 * Should be called when done using mosh.
 */
FFI_PLUGIN_EXPORT void mosh_cleanup(void);

/*
 * Create a new mosh session.
 *
 * @param host     The server hostname or IP
 * @param port     The UDP port (from mosh-server)
 * @param key      The base64 session key (from mosh-server)
 * @param width    Initial terminal width
 * @param height   Initial terminal height
 * @return         Session handle or NULL on error
 */
FFI_PLUGIN_EXPORT MoshSession mosh_session_create(
    const char* host,
    const char* port,
    const char* key,
    int width,
    int height
);

/*
 * Set callbacks for the session.
 */
FFI_PLUGIN_EXPORT void mosh_session_set_callbacks(
    MoshSession session,
    MoshScreenCallback screen_cb,
    MoshErrorCallback error_cb,
    MoshStateCallback state_cb,
    void* user_data
);

/*
 * Connect the session.
 * This starts the network thread.
 * Returns MOSH_OK on success.
 */
FFI_PLUGIN_EXPORT MoshResult mosh_session_connect(MoshSession session);

/*
 * Send user input to the session.
 *
 * @param session  The session handle
 * @param data     The input data (UTF-8)
 * @param len      Length of input data
 * @return         MOSH_OK on success
 */
FFI_PLUGIN_EXPORT MoshResult mosh_session_write(
    MoshSession session,
    const char* data,
    size_t len
);

/*
 * Resize the terminal.
 *
 * @param session  The session handle
 * @param width    New width
 * @param height   New height
 * @return         MOSH_OK on success
 */
FFI_PLUGIN_EXPORT MoshResult mosh_session_resize(
    MoshSession session,
    int width,
    int height
);

/*
 * Poll for updates.
 * Should be called periodically to process network events.
 * This will trigger callbacks if there are updates.
 *
 * @param session       The session handle
 * @param timeout_ms    Timeout in milliseconds (0 for non-blocking)
 * @return              MOSH_OK on success
 */
FFI_PLUGIN_EXPORT MoshResult mosh_session_poll(
    MoshSession session,
    int timeout_ms
);

/*
 * Get current session state.
 */
FFI_PLUGIN_EXPORT MoshState mosh_session_get_state(MoshSession session);

/*
 * Get last error message.
 * Returns NULL if no error.
 */
FFI_PLUGIN_EXPORT const char* mosh_session_get_error(MoshSession session);

/*
 * Disconnect and destroy the session.
 */
FFI_PLUGIN_EXPORT void mosh_session_destroy(MoshSession session);

/*
 * Get library version string.
 */
FFI_PLUGIN_EXPORT const char* mosh_version(void);

#ifdef __cplusplus
}
#endif

#endif /* MOSH_FFI_H */
