# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY src/headless/package*.json ./src/headless/
COPY src/log/package*.json ./src/log/

# Install dependencies
RUN npm ci --prefer-offline --no-audit

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM nginx:alpine

# Install Node.js for http-server and envsubst for template processing
RUN apk add --no-cache nodejs npm gettext && \
    npm install -g http-server@14.1.0 && \
    apk del npm

# Copy built files from builder
COPY --from=builder /app/dist /app/dist
COPY --from=builder /app/*.html /app/
COPY --from=builder /app/images /app/images
COPY --from=builder /app/sounds /app/sounds
COPY --from=builder /app/logo /app/logo
COPY --from=builder /app/3rdparty /app/3rdparty
COPY --from=builder /app/src/website.js /app/src/website.js
COPY --from=builder /app/manifest.json /app/

# Create template for fullscreen.html
RUN cat > /app/fullscreen.html.template << 'EOF'
<!doctype html>
<html class="no-js" lang="en">
<head>
    <title>${APP_TITLE}</title>
    <meta charset="utf-8"/>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <meta name="description" content="${APP_DESCRIPTION}"/>
    <meta name="author" content="${APP_AUTHOR}" />
    <meta name="keywords" content="xmpp chat webchat converse.js" />
    <link rel="shortcut icon" type="image/ico" href="/dist/images/favicon.ico"/>
    <link rel="manifest" href="./manifest.json">
    <link type="text/css" rel="stylesheet" media="screen" href="/dist/converse.min.css" />
    <script src="https://cdn.conversejs.org/3rdparty/libsignal-protocol.min.js"></script>
    <script src="/dist/converse.min.js"></script>
</head>
<body class="converse-fullscreen">
<noscript>You need to enable JavaScript to run the Converse.js chat app.</noscript>
<div id="conversejs-bg"></div>
<script>
    converse.initialize({
        theme: '${CONVERSE_THEME}',
        dark_theme: '${CONVERSE_DARK_THEME}',
        authentication: '${CONVERSE_AUTHENTICATION}',
        auto_login: ${CONVERSE_AUTO_LOGIN},
        auto_away: ${CONVERSE_AUTO_AWAY},
        auto_xa: ${CONVERSE_AUTO_XA},
        auto_reconnect: ${CONVERSE_AUTO_RECONNECT},
        bosh_service_url: '${CONVERSE_BOSH_SERVICE_URL}',
        websocket_url: '${CONVERSE_WEBSOCKET_URL}',
        message_archiving: '${CONVERSE_MESSAGE_ARCHIVING}',
        view_mode: '${CONVERSE_VIEW_MODE}',
        show_background: ${CONVERSE_SHOW_BACKGROUND},
        jid: '${CONVERSE_JID}',
        keepalive: ${CONVERSE_KEEPALIVE},
        allow_logout: ${CONVERSE_ALLOW_LOGOUT},
        allow_registration: ${CONVERSE_ALLOW_REGISTRATION},
        play_sounds: ${CONVERSE_PLAY_SOUNDS},
        show_desktop_notifications: ${CONVERSE_SHOW_DESKTOP_NOTIFICATIONS},
        notification_delay: ${CONVERSE_NOTIFICATION_DELAY},
        show_chat_state_notifications: ${CONVERSE_SHOW_CHAT_STATE_NOTIFICATIONS},
        show_controlbox_by_default: ${CONVERSE_SHOW_CONTROLBOX_BY_DEFAULT},
        sticky_controlbox: ${CONVERSE_STICKY_CONTROLBOX},
        default_domain: '${CONVERSE_DEFAULT_DOMAIN}',
        locked_domain: '${CONVERSE_LOCKED_DOMAIN}',
        muc_domain: '${CONVERSE_MUC_DOMAIN}',
        locked_muc_domain: ${CONVERSE_LOCKED_MUC_DOMAIN},
        muc_nickname_from_jid: ${CONVERSE_MUC_NICKNAME_FROM_JID},
        omemo_default: ${CONVERSE_OMEMO_DEFAULT},
        priority: ${CONVERSE_PRIORITY},
        auto_subscribe: ${CONVERSE_AUTO_SUBSCRIBE},
        allow_contact_removal: ${CONVERSE_ALLOW_CONTACT_REMOVAL},
        allow_contact_requests: ${CONVERSE_ALLOW_CONTACT_REQUESTS},
        allow_non_roster_messaging: ${CONVERSE_ALLOW_NON_ROSTER_MESSAGING},
        allow_bookmarks: ${CONVERSE_ALLOW_BOOKMARKS},
        allow_public_bookmarks: ${CONVERSE_ALLOW_PUBLIC_BOOKMARKS},
        auto_list_rooms: ${CONVERSE_AUTO_LIST_ROOMS},
        allow_muc_invitations: ${CONVERSE_ALLOW_MUC_INVITATIONS},
        render_media: ${CONVERSE_RENDER_MEDIA},
        show_images_inline: ${CONVERSE_SHOW_IMAGES_INLINE},
        show_send_button: ${CONVERSE_SHOW_SEND_BUTTON},
        show_retraction_warning: ${CONVERSE_SHOW_RETRACTION_WARNING},
        allow_message_corrections: '${CONVERSE_ALLOW_MESSAGE_CORRECTIONS}',
        allow_message_retraction: '${CONVERSE_ALLOW_MESSAGE_RETRACTION}',
        allow_message_styling: ${CONVERSE_ALLOW_MESSAGE_STYLING},
        show_message_avatar: ${CONVERSE_SHOW_MESSAGE_AVATAR},
        colorize_username: ${CONVERSE_COLORIZE_USERNAME},
        use_system_emojis: ${CONVERSE_USE_SYSTEM_EMOJIS},
        i18n: '${CONVERSE_I18N}',
        roster_groups: ${CONVERSE_ROSTER_GROUPS},
        hide_offline_users: ${CONVERSE_HIDE_OFFLINE_USERS},
        archived_messages_page_size: ${CONVERSE_ARCHIVED_MESSAGES_PAGE_SIZE},
        message_archiving_timeout: ${CONVERSE_MESSAGE_ARCHIVING_TIMEOUT},
        csi_waiting_time: ${CONVERSE_CSI_WAITING_TIME},
        idle_presence_timeout: ${CONVERSE_IDLE_PRESENCE_TIMEOUT},
        ping_interval: ${CONVERSE_PING_INTERVAL},
        enable_smacks: ${CONVERSE_ENABLE_SMACKS},
        clear_cache_on_logout: ${CONVERSE_CLEAR_CACHE_ON_LOGOUT},
        persistent_store: '${CONVERSE_PERSISTENT_STORE}',
    });
</script>
</body>
</html>
EOF

# Create entrypoint script
RUN cat > /app/entrypoint.sh << 'EOF'
#!/bin/sh
set -e

# Set defaults for all environment variables
export APP_TITLE="${APP_TITLE:-Converse}"
export APP_DESCRIPTION="${APP_DESCRIPTION:-Converse XMPP/Jabber Chat}"
export APP_AUTHOR="${APP_AUTHOR:-JC Brand}"
export CONVERSE_THEME="${CONVERSE_THEME:-default}"
export CONVERSE_DARK_THEME="${CONVERSE_DARK_THEME:-dracula}"
export CONVERSE_AUTHENTICATION="${CONVERSE_AUTHENTICATION:-login}"
export CONVERSE_AUTO_LOGIN="${CONVERSE_AUTO_LOGIN:-false}"
export CONVERSE_AUTO_AWAY="${CONVERSE_AUTO_AWAY:-300}"
export CONVERSE_AUTO_XA="${CONVERSE_AUTO_XA:-900}"
export CONVERSE_AUTO_RECONNECT="${CONVERSE_AUTO_RECONNECT:-true}"
export CONVERSE_BOSH_SERVICE_URL="${CONVERSE_BOSH_SERVICE_URL:-https://conversejs.org/http-bind/}"
export CONVERSE_WEBSOCKET_URL="${CONVERSE_WEBSOCKET_URL:-}"
export CONVERSE_MESSAGE_ARCHIVING="${CONVERSE_MESSAGE_ARCHIVING:-always}"
export CONVERSE_VIEW_MODE="${CONVERSE_VIEW_MODE:-fullscreen}"
export CONVERSE_SHOW_BACKGROUND="${CONVERSE_SHOW_BACKGROUND:-true}"
export CONVERSE_JID="${CONVERSE_JID:-}"
export CONVERSE_KEEPALIVE="${CONVERSE_KEEPALIVE:-true}"
export CONVERSE_ALLOW_LOGOUT="${CONVERSE_ALLOW_LOGOUT:-true}"
export CONVERSE_ALLOW_REGISTRATION="${CONVERSE_ALLOW_REGISTRATION:-true}"
export CONVERSE_PLAY_SOUNDS="${CONVERSE_PLAY_SOUNDS:-false}"
export CONVERSE_SHOW_DESKTOP_NOTIFICATIONS="${CONVERSE_SHOW_DESKTOP_NOTIFICATIONS:-true}"
export CONVERSE_NOTIFICATION_DELAY="${CONVERSE_NOTIFICATION_DELAY:-5000}"
export CONVERSE_SHOW_CHAT_STATE_NOTIFICATIONS="${CONVERSE_SHOW_CHAT_STATE_NOTIFICATIONS:-false}"
export CONVERSE_SHOW_CONTROLBOX_BY_DEFAULT="${CONVERSE_SHOW_CONTROLBOX_BY_DEFAULT:-false}"
export CONVERSE_STICKY_CONTROLBOX="${CONVERSE_STICKY_CONTROLBOX:-false}"
export CONVERSE_DEFAULT_DOMAIN="${CONVERSE_DEFAULT_DOMAIN:-}"
export CONVERSE_LOCKED_DOMAIN="${CONVERSE_LOCKED_DOMAIN:-}"
export CONVERSE_MUC_DOMAIN="${CONVERSE_MUC_DOMAIN:-}"
export CONVERSE_LOCKED_MUC_DOMAIN="${CONVERSE_LOCKED_MUC_DOMAIN:-false}"
export CONVERSE_MUC_NICKNAME_FROM_JID="${CONVERSE_MUC_NICKNAME_FROM_JID:-false}"
export CONVERSE_OMEMO_DEFAULT="${CONVERSE_OMEMO_DEFAULT:-false}"
export CONVERSE_PRIORITY="${CONVERSE_PRIORITY:-0}"
export CONVERSE_AUTO_SUBSCRIBE="${CONVERSE_AUTO_SUBSCRIBE:-false}"
export CONVERSE_ALLOW_CONTACT_REMOVAL="${CONVERSE_ALLOW_CONTACT_REMOVAL:-true}"
export CONVERSE_ALLOW_CONTACT_REQUESTS="${CONVERSE_ALLOW_CONTACT_REQUESTS:-true}"
export CONVERSE_ALLOW_NON_ROSTER_MESSAGING="${CONVERSE_ALLOW_NON_ROSTER_MESSAGING:-false}"
export CONVERSE_ALLOW_BOOKMARKS="${CONVERSE_ALLOW_BOOKMARKS:-true}"
export CONVERSE_ALLOW_PUBLIC_BOOKMARKS="${CONVERSE_ALLOW_PUBLIC_BOOKMARKS:-false}"
export CONVERSE_AUTO_LIST_ROOMS="${CONVERSE_AUTO_LIST_ROOMS:-false}"
export CONVERSE_ALLOW_MUC_INVITATIONS="${CONVERSE_ALLOW_MUC_INVITATIONS:-true}"
export CONVERSE_RENDER_MEDIA="${CONVERSE_RENDER_MEDIA:-true}"
export CONVERSE_SHOW_IMAGES_INLINE="${CONVERSE_SHOW_IMAGES_INLINE:-true}"
export CONVERSE_SHOW_SEND_BUTTON="${CONVERSE_SHOW_SEND_BUTTON:-true}"
export CONVERSE_SHOW_RETRACTION_WARNING="${CONVERSE_SHOW_RETRACTION_WARNING:-true}"
export CONVERSE_ALLOW_MESSAGE_CORRECTIONS="${CONVERSE_ALLOW_MESSAGE_CORRECTIONS:-all}"
export CONVERSE_ALLOW_MESSAGE_RETRACTION="${CONVERSE_ALLOW_MESSAGE_RETRACTION:-all}"
export CONVERSE_ALLOW_MESSAGE_STYLING="${CONVERSE_ALLOW_MESSAGE_STYLING:-true}"
export CONVERSE_SHOW_MESSAGE_AVATAR="${CONVERSE_SHOW_MESSAGE_AVATAR:-true}"
export CONVERSE_COLORIZE_USERNAME="${CONVERSE_COLORIZE_USERNAME:-false}"
export CONVERSE_USE_SYSTEM_EMOJIS="${CONVERSE_USE_SYSTEM_EMOJIS:-true}"
export CONVERSE_I18N="${CONVERSE_I18N:-en}"
export CONVERSE_ROSTER_GROUPS="${CONVERSE_ROSTER_GROUPS:-true}"
export CONVERSE_HIDE_OFFLINE_USERS="${CONVERSE_HIDE_OFFLINE_USERS:-false}"
export CONVERSE_ARCHIVED_MESSAGES_PAGE_SIZE="${CONVERSE_ARCHIVED_MESSAGES_PAGE_SIZE:-50}"
export CONVERSE_MESSAGE_ARCHIVING_TIMEOUT="${CONVERSE_MESSAGE_ARCHIVING_TIMEOUT:-20000}"
export CONVERSE_CSI_WAITING_TIME="${CONVERSE_CSI_WAITING_TIME:-0}"
export CONVERSE_IDLE_PRESENCE_TIMEOUT="${CONVERSE_IDLE_PRESENCE_TIMEOUT:-300}"
export CONVERSE_PING_INTERVAL="${CONVERSE_PING_INTERVAL:-60}"
export CONVERSE_ENABLE_SMACKS="${CONVERSE_ENABLE_SMACKS:-true}"
export CONVERSE_CLEAR_CACHE_ON_LOGOUT="${CONVERSE_CLEAR_CACHE_ON_LOGOUT:-false}"
export CONVERSE_PERSISTENT_STORE="${CONVERSE_PERSISTENT_STORE:-IndexedDB}"

# Generate fullscreen.html from template
envsubst < /app/fullscreen.html.template > /app/fullscreen.html

# Create simple redirect from index.html to fullscreen.html
echo '<!DOCTYPE html><html><head><meta http-equiv="refresh" content="0;url=/fullscreen.html"></head><body>Redirecting...</body></html>' > /app/index.html

# Start http-server
exec http-server -p 8080 -c-1 --cors
EOF

RUN chmod +x /app/entrypoint.sh

WORKDIR /app

# Expose port
EXPOSE 8080

# Use entrypoint script
ENTRYPOINT ["/app/entrypoint.sh"]
