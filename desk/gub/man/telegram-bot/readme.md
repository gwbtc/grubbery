# Telegram Bot

Chat interface for a single Telegram bot. Long-polls Telegram's getUpdates API and maintains per-chat message logs in `messages/[chat-id].json`. Each file: `{"name": "...", "chat-id": "...", "messages": [...]}`. Configure `/config.json` with bot-token. View chat at `/ui/chat.html`.

## Files

- `offset.ud` — Telegram update offset.
- `config.json` — Bot config: bot-token.
- `send.sig` — Accepts JSON pokes with chat_id and message. Sends as bot.
- `poller.sig` — Long-polling loop for incoming messages.
