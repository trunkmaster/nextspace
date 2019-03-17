/* -*- mode: objc -*- */
//
// Project: SoundKit framework.
//
// Copyright (C) 2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#import <pulse/pulseaudio.h>
#import <pulse/ext-stream-restore.h>
#import <pulse/ext-device-manager.h>

@interface SKSoundServer (Callbacks)

// --- Server ---
void server_info_cb(pa_context *ctx, const pa_server_info *info, void *userdata);
void card_cb(pa_context *ctx, const pa_card_info *info, int eol, void *userdata);

// --- Sink ---
void sink_cb(pa_context *ctx, const pa_sink_info *info, int eol, void *userdata);
// --- Source ---
void source_cb(pa_context *ctx, const pa_source_info *info,
               int eol, void *userdata);

// --- Client ---
void sink_input_cb(pa_context *ctx, const pa_sink_input_info *info,
                   int eol, void *userdata);
void source_output_cb(pa_context *ctx, const pa_source_output_info *info,
                      int eol, void *userdata);
void client_cb(pa_context *ctx, const pa_client_info *info, int eol, void *userdata);

// --- Saved Streams ---
void ext_stream_restore_read_cb(pa_context *ctx,
                                const pa_ext_stream_restore_info *info,
                                int eol, void *userdata);

// --- Context events ---
void context_subscribe_cb(pa_context *ctx, pa_subscription_event_type_t event_type,
                          uint32_t index, void *userdata);
void context_state_cb(pa_context *ctx, void *userdata);

// --- Initial objects inventory ---
void inventory_start(pa_context *ctx, void *userdata);
void inventory_decrement_requests(pa_context *ctx, void *userdata);
void inventory_end(pa_context *ctx, void *userdata);


@end
