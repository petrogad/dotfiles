---
name: discord-announce
description: Draft and post an announcement to a project's Discord server through the Kreinto Discord bot — a shipped feature, a release, downtime, a changelog. Always shows Pete the exact message and waits for his approval before posting; can edit or delete a post it made. Use when asked to "announce X in Discord", "post this to Discord", "tell the community about Y", or to fix/retract an earlier announcement.
argument-hint: '<what to announce> [--project <name>] [--channel <name>] | edit <message-id> | delete <message-id>'
---

# Announce in Discord

Posting is **outward-facing and public**: a community sees it the moment it lands, and it may be
screenshotted or cached even if deleted. So the rule that governs everything below is:
**Pete approves the exact bytes before they are sent.** No approval in this conversation, no post.
Approval of one message never covers a second one or an edit.

Posts go through **the Kreinto Discord bot** and its bot token, using Discord's REST API
(`https://discord.com/api/v10`). The bot is a member of each project's server. It can only post
where its role has **View Channel** and **Send Messages** (plus **Attach Files** for
screenshots), so channel permissions are the real boundary. Keep the bot's role narrow; it
doesn't need admin.

## 1. Resolve the token and the channel

The project is the repo name from the origin remote (`flugo`), unless `--project` says otherwise.
It comes from the remote, not the directory, because in the clone-for-wt layout the directory is
the worktree (`main`, a branch name). The channel defaults to `announcements`.

```bash
project="${PROJECT:-$(basename "$(git remote get-url origin 2>/dev/null)" .git)}"
: "${project:?not in a repo with an origin remote. Ask which project this is for}"
channel="${CHANNEL:-announcements}"

# Agent shells don't source .zshrc → .zshrc.local, so load it explicitly (it also carries
# OP_SERVICE_ACCOUNT_TOKEN, which `op` needs).
[ ! -f ~/.zshrc.local ] || source ~/.zshrc.local

# The token: env first, then 1Password. The agent's service account can read ONLY the
# 'Kreinto Infra' vault, so the item must live there.
token="${DISCORD_BOT_TOKEN:-}"
[ -n "$token" ] || ! command -v op >/dev/null || \
  token=$(op read "${DISCORD_BOT_TOKEN_REF:-op://Kreinto Infra/discord-bot-token/credential}" 2>/dev/null || true)

api=https://discord.com/api/v10
ua='DiscordBot (https://github.com/kreinto-io, 1.0)'      # Discord requires this User-Agent format
```

**Never print, echo, log or commit the token.** It controls the bot on every server it's in. Send
it only in the `Authorization: Bot …` header, and keep it out of your visible output.

**If the token is missing:** the service account can't see it. Ask Pete to store it in vault
**Kreinto Infra** as an API Credential named `discord-bot-token`, with the token in field
`credential`. Or, if he keeps it elsewhere, have him set `DISCORD_BOT_TOKEN_REF` to its
`op://…` reference in `~/.zshrc.local`. Meanwhile, hand him the approved draft to paste by hand,
so the announcement isn't lost.

**Resolve the channel id once per project, then cache it.** Channel ids aren't secret, so they
live in a plain JSON map:

```bash
map="${AGENT_WORK_DIR:-$HOME/agents}/discord/channels.json"; mkdir -p "$(dirname "$map")"
[ -f "$map" ] || echo '{}' > "$map"
channel_id=$(jq -r --arg k "$project/$channel" '.[$k] // empty' "$map")
if [ -z "$channel_id" ]; then
  auth=(-H "Authorization: Bot $token" -H "User-Agent: $ua")
  guilds=$(curl -sf "${auth[@]}" "$api/users/@me/guilds")      # servers the bot is in
  # Pick the project's server by name with Pete if more than one could match — never guess.
  # Then find the text channel (type 0 = text, 5 = announcement):
  #   curl -sf "${auth[@]}" "$api/guilds/$guild_id/channels" \
  #     | jq -r --arg n "$channel" '.[] | select(.name==$n and (.type==0 or .type==5)) | .id'
  # Confirm the server + channel with Pete, then cache:
  #   jq --arg k "$project/$channel" --arg v "$channel_id" --arg g "$guild_id" \
  #     '.[$k]=$v | .[$k+"#guild"]=$g' "$map" > "$map.tmp" && mv "$map.tmp" "$map"
fi
```

## 2. Ground the content in what actually shipped

An announcement is a claim to users, so verify it before drafting:

- **What changed:** read the PR (`gh pr view <n> --json title,body`) and the diff stat. Describe
  only what the change does, not what the PR hoped or deferred.
- **Is it live?** Check that the deploy for a commit at or after the change succeeded
  (`gh run list --branch <default> --limit 5`). If it isn't deployed yet, say so and ask whether
  to wait. Announcing a feature users can't reach yet is worse than a late post.
- **Who can use it:** roles, plans and platforms. "Coaches can…" vs "everyone can…" matters.

## 3. Draft

House style for a community announcement:

- A bold one-line headline with **one** emoji, then 2–5 short bullets, then a line on where to
  find it ("Sign in → pick your team → **Roster**"). Keep it well under Discord's 2000-character
  message limit; aim for something that fits on a phone screen without scrolling.
- **User language only.** No PR numbers, work-item IDs, internal codenames, test counts, endpoint
  paths or implementation detail. Lead with what the reader can now *do*.
- **No mentions by default.** No `@everyone` or `@here` unless Pete asks, and the payload below
  sets `allowed_mentions` to nothing, so a stray `@` can't ping anyone either.
- Offer a screenshot when the feature is visual. Attachments are posted as files (§4).

Show Pete the **exact message** in a fenced block, exactly as it will render, and ask him to
approve or edit it. Iterate until he says post.

## 4. Post (only after explicit approval)

Build the JSON with `jq` (never by string interpolation):

```bash
auth=(-H "Authorization: Bot $token" -H "User-Agent: $ua")
body=$(jq -n --arg c "$content" '{content: $c, allowed_mentions: {parse: []}}')
resp=$(curl -sf -X POST "$api/channels/$channel_id/messages" "${auth[@]}" \
  -H 'Content-Type: application/json' -d "$body")
msg_id=$(jq -r .id <<<"$resp")
```

With an image, send multipart and put the JSON in `payload_json`:

```bash
curl -sf -X POST "$api/channels/$channel_id/messages" "${auth[@]}" \
  -F "payload_json=$body" -F "files[0]=@/path/to/screenshot.png"
```

An **announcement channel** (type 5) also lets you *publish* the message to servers that follow
it: `POST $api/channels/$channel_id/messages/$msg_id/crosspost`. That's a second public act, so
ask Pete separately.

On failure, retry once. A 429 carries `retry_after` in seconds, so wait that long before
retrying.
- **401:** the token was reset. Re-file the §1 ask.
- **403:** the bot's role lacks permission in that channel. Tell Pete which permission is
  missing.
- **404:** the channel is gone. Drop it from `channels.json` and re-resolve.

If it still fails, give Pete the final text to paste. Never report a post that didn't happen.

Record every post so a later session can edit it. The log holds ids only, never the token:

```bash
log="${AGENT_WORK_DIR:-$HOME/agents}/discord/$project.jsonl"
jq -nc --arg id "$msg_id" --arg ch "$channel_id" --arg c "$content" --arg at "$(date -u +%FT%TZ)" \
  '{id:$id, channel_id:$ch, at:$at, content:$c}' >> "$log"
```

Report back with the link `https://discord.com/channels/<guild_id>/<channel_id>/<msg_id>`, where
`guild_id` is cached beside the channel in `channels.json`.

## 5. Edit or delete a post

Only edit or delete messages the bot itself posted and that are in the log. An edit is a new
approval: show Pete the new text first.

```bash
curl -sf -X PATCH "$api/channels/$channel_id/messages/$msg_id" "${auth[@]}" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg c "$content" '{content: $c, allowed_mentions: {parse: []}}')"
curl -sf -X DELETE "$api/channels/$channel_id/messages/$msg_id" "${auth[@]}"   # only when Pete asks
```

Append edits and deletes to the log as `{id, action: "edit"|"delete", at}`.
