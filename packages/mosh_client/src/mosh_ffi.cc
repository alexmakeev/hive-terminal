/*
 * MOSH FFI Wrapper Implementation
 *
 * Wraps the mosh C++ library with a C interface for Dart FFI.
 */

#include "mosh_ffi.h"

#include <string>
#include <thread>
#include <mutex>
#include <atomic>
#include <memory>
#include <cstring>
#include <sys/select.h>

// Mosh includes
#include "config.h"
#include "fatal_assert.h"
#include "crypto.h"
#include "network.h"
#include "networktransport.h"
#include "networktransport-impl.h"
#include "transportsender.h"
#include "transportsender-impl.h"
#include "completeterminal.h"
#include "user.h"
#include "locale_utils.h"
#include "terminalframebuffer.h"

using namespace std;
using namespace Network;
using namespace Terminal;

// Internal session structure
struct MoshSessionImpl {
    // Connection parameters
    string host;
    string port;
    string key;
    int width;
    int height;

    // State
    atomic<MoshState> state{MOSH_STATE_DISCONNECTED};
    string last_error;
    mutex error_mutex;

    // Callbacks
    MoshScreenCallback screen_cb = nullptr;
    MoshErrorCallback error_cb = nullptr;
    MoshStateCallback state_cb = nullptr;
    void* user_data = nullptr;

    // Initial states (must persist for lifetime of transport)
    unique_ptr<UserStream> user_stream;
    unique_ptr<Complete> initial_remote;

    // Network
    typedef Transport<UserStream, Complete> NetworkType;
    unique_ptr<NetworkType> network;

    void set_error(const string& msg) {
        lock_guard<mutex> lock(error_mutex);
        last_error = msg;
        state = MOSH_STATE_ERROR;
        if (error_cb) {
            error_cb(msg.c_str(), user_data);
        }
        if (state_cb) {
            state_cb(MOSH_STATE_ERROR, user_data);
        }
    }

    void set_state(MoshState new_state) {
        state = new_state;
        if (state_cb) {
            state_cb(new_state, user_data);
        }
    }
};

// Library state
static atomic<bool> g_initialized{false};

extern "C" {

FFI_PLUGIN_EXPORT MoshResult mosh_init(void) {
    if (g_initialized.exchange(true)) {
        return MOSH_OK; // Already initialized
    }

    // Disable core dumps for security
    Crypto::disable_dumping_core();

    // Set native locale
    set_native_locale();

    return MOSH_OK;
}

FFI_PLUGIN_EXPORT void mosh_cleanup(void) {
    g_initialized = false;
}

FFI_PLUGIN_EXPORT MoshSession mosh_session_create(
    const char* host,
    const char* port,
    const char* key,
    int width,
    int height
) {
    if (!host || !port || !key || width <= 0 || height <= 0) {
        return nullptr;
    }

    try {
        auto session = new MoshSessionImpl();
        session->host = host;
        session->port = port;
        session->key = key;
        session->width = width;
        session->height = height;

        // Initialize states
        session->user_stream = make_unique<UserStream>();
        session->initial_remote = make_unique<Complete>(width, height);

        return session;
    } catch (const exception& e) {
        return nullptr;
    }
}

FFI_PLUGIN_EXPORT void mosh_session_set_callbacks(
    MoshSession session,
    MoshScreenCallback screen_cb,
    MoshErrorCallback error_cb,
    MoshStateCallback state_cb,
    void* user_data
) {
    if (!session) return;

    auto impl = static_cast<MoshSessionImpl*>(session);
    impl->screen_cb = screen_cb;
    impl->error_cb = error_cb;
    impl->state_cb = state_cb;
    impl->user_data = user_data;
}

FFI_PLUGIN_EXPORT MoshResult mosh_session_connect(MoshSession session) {
    if (!session) return MOSH_ERROR_INVALID_PARAMS;

    auto impl = static_cast<MoshSessionImpl*>(session);

    if (impl->state != MOSH_STATE_DISCONNECTED) {
        return MOSH_ERROR_INVALID_PARAMS;
    }

    impl->set_state(MOSH_STATE_CONNECTING);

    try {
        // Create network transport
        // Constructor: Transport(MyState&, RemoteState&, key, ip, port)
        impl->network = make_unique<MoshSessionImpl::NetworkType>(
            *(impl->user_stream),
            *(impl->initial_remote),
            impl->key.c_str(),
            impl->host.c_str(),
            impl->port.c_str()
        );

        // Stay in CONNECTING state until we receive first packet
        // State will be updated to CONNECTED in poll() when remote_state_num > 0
        return MOSH_OK;

    } catch (const NetworkException& e) {
        impl->set_error(string("Network error: ") + e.what());
        return MOSH_ERROR_NETWORK;
    } catch (const CryptoException& e) {
        impl->set_error(string("Crypto error: ") + e.what());
        return MOSH_ERROR_CRYPTO;
    } catch (const exception& e) {
        impl->set_error(string("Error: ") + e.what());
        return MOSH_ERROR_CONNECT_FAILED;
    }
}

FFI_PLUGIN_EXPORT MoshResult mosh_session_write(
    MoshSession session,
    const char* data,
    size_t len
) {
    if (!session || !data) return MOSH_ERROR_INVALID_PARAMS;

    auto impl = static_cast<MoshSessionImpl*>(session);

    if (impl->state != MOSH_STATE_CONNECTED || !impl->network) {
        return MOSH_ERROR_NOT_CONNECTED;
    }

    try {
        // Send user input through the network
        for (size_t i = 0; i < len; i++) {
            impl->network->get_current_state().push_back(
                Parser::UserByte(data[i])
            );
        }
        return MOSH_OK;
    } catch (const exception& e) {
        impl->set_error(e.what());
        return MOSH_ERROR_NETWORK;
    }
}

FFI_PLUGIN_EXPORT MoshResult mosh_session_resize(
    MoshSession session,
    int width,
    int height
) {
    if (!session || width <= 0 || height <= 0) {
        return MOSH_ERROR_INVALID_PARAMS;
    }

    auto impl = static_cast<MoshSessionImpl*>(session);

    if (impl->state != MOSH_STATE_CONNECTED || !impl->network) {
        return MOSH_ERROR_NOT_CONNECTED;
    }

    try {
        impl->width = width;
        impl->height = height;

        // Notify network of resize
        impl->network->get_current_state().push_back(
            Parser::Resize(width, height)
        );
        return MOSH_OK;
    } catch (const exception& e) {
        impl->set_error(e.what());
        return MOSH_ERROR_NETWORK;
    }
}

FFI_PLUGIN_EXPORT MoshResult mosh_session_poll(
    MoshSession session,
    int timeout_ms
) {
    if (!session) return MOSH_ERROR_INVALID_PARAMS;

    auto impl = static_cast<MoshSessionImpl*>(session);

    // Allow polling in CONNECTING or CONNECTED states
    if ((impl->state != MOSH_STATE_CONNECTING && impl->state != MOSH_STATE_CONNECTED)
        || !impl->network) {
        return MOSH_ERROR_NOT_CONNECTED;
    }

    try {
        // Wait for socket data using select
        auto fds = impl->network->fds();
        bool has_data = false;

        if (!fds.empty()) {
            fd_set readfds;
            FD_ZERO(&readfds);
            int max_fd = -1;
            for (int fd : fds) {
                FD_SET(fd, &readfds);
                if (fd > max_fd) max_fd = fd;
            }

            struct timeval tv;
            tv.tv_sec = timeout_ms / 1000;
            tv.tv_usec = (timeout_ms % 1000) * 1000;

            int ret = select(max_fd + 1, &readfds, nullptr, nullptr, &tv);
            has_data = (ret > 0);
        }

        // Tick the network (process pending I/O)
        impl->network->tick();

        // Receive any pending data only if select indicated data is available
        if (has_data) {
            impl->network->recv();
        }

        // Check if we've received remote state (means we're truly connected)
        if (impl->network->get_remote_state_num() > 0) {
            if (impl->state == MOSH_STATE_CONNECTING) {
                impl->set_state(MOSH_STATE_CONNECTED);
            }
        }

        // Get screen updates if we have a callback and are connected
        if (impl->state == MOSH_STATE_CONNECTED &&
            impl->network->get_remote_state_num() > 0 && impl->screen_cb) {
            // Get the current framebuffer from the latest remote state
            const Complete& remote_state = impl->network->get_latest_remote_state().state;
            const Framebuffer& fb = remote_state.get_fb();

            int w = fb.ds.get_width();
            int h = fb.ds.get_height();

            // Allocate cells
            vector<MoshCell> cells(w * h);

            for (int row = 0; row < h; row++) {
                const Row* r = fb.get_row(row);
                if (!r) continue;

                for (int col = 0; col < w && col < (int)r->cells.size(); col++) {
                    const Cell& c = r->cells.at(col);
                    MoshCell& mc = cells[row * w + col];

                    // Get cell content using debug_contents
                    string contents = c.debug_contents();
                    if (contents.empty()) {
                        mc.codepoint = ' ';
                    } else {
                        // Convert UTF-8 to codepoint (first char for simplicity)
                        mc.codepoint = (uint8_t)contents[0];
                    }

                    // Get attributes
                    const Renditions& rend = c.get_renditions();
                    // Colors are private in mosh API, use defaults
                    mc.foreground = 7; // Default white
                    mc.background = 0; // Default black
                    mc.bold = rend.get_attribute(Renditions::bold) ? 1 : 0;
                    mc.underline = rend.get_attribute(Renditions::underlined) ? 1 : 0;
                    mc.blink = rend.get_attribute(Renditions::blink) ? 1 : 0;
                    mc.inverse = rend.get_attribute(Renditions::inverse) ? 1 : 0;
                }
            }

            // Get cursor position
            int cursor_x = fb.ds.get_cursor_col();
            int cursor_y = fb.ds.get_cursor_row();

            impl->screen_cb(
                cells.data(),
                w, h,
                cursor_x, cursor_y,
                impl->user_data
            );
        }

        return MOSH_OK;
    } catch (const exception& e) {
        impl->set_error(e.what());
        return MOSH_ERROR_NETWORK;
    }
}

FFI_PLUGIN_EXPORT MoshState mosh_session_get_state(MoshSession session) {
    if (!session) return MOSH_STATE_DISCONNECTED;

    auto impl = static_cast<MoshSessionImpl*>(session);
    return impl->state.load();
}

FFI_PLUGIN_EXPORT const char* mosh_session_get_error(MoshSession session) {
    if (!session) return nullptr;

    auto impl = static_cast<MoshSessionImpl*>(session);
    lock_guard<mutex> lock(impl->error_mutex);
    return impl->last_error.empty() ? nullptr : impl->last_error.c_str();
}

FFI_PLUGIN_EXPORT void mosh_session_destroy(MoshSession session) {
    if (!session) return;

    auto impl = static_cast<MoshSessionImpl*>(session);

    // Cleanup network
    if (impl->network) {
        impl->network->start_shutdown();
    }

    delete impl;
}

FFI_PLUGIN_EXPORT const char* mosh_version(void) {
    return "mosh-ffi 0.1.0 (based on mosh " PACKAGE_VERSION ")";
}

} // extern "C"
