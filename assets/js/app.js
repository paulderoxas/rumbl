import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/rumbl"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Load YouTube IFrame API
let ytApiReady = false;
const ytApiCallbacks = [];

window.onYouTubeIframeAPIReady = function () {
  ytApiReady = true;
  ytApiCallbacks.forEach(fn => fn());
};

function onYTReady(fn) {
  if (ytApiReady) {
    fn();
  } else {
    ytApiCallbacks.push(fn);
  }
}

const ytScript = document.createElement("script");
ytScript.src = "https://www.youtube.com/iframe_api";
document.head.appendChild(ytScript);

// Video Channel for Real-time Annotations
const Video = {
  player: null,

  init(socket, element) {
    if (!element) return;

    const videoId = element.dataset.id;
    const currentUserId = parseInt(element.dataset.userId) || null;
    const channel = socket.channel(`video:${videoId}`, {});

    channel.on("new_annotation", (resp) => {
      this.renderAnnotation(resp, currentUserId, channel);
    });

    channel.on("annotation_deleted", ({ id }) => {
      const el = document.querySelector(`.annotation[data-id="${id}"]`);
      if (el) el.remove();
    });

    channel
      .join()
      .receive("ok", (resp) => {
        console.log("Joined video channel", resp);
      })
      .receive("error", (reason) => {
        console.error("Join failed", reason);
      });

    // Use event delegation on the annotations container so it works for
    // both server-rendered and dynamically added annotations
    const annotationsContainer = document.getElementById("annotations");
    if (annotationsContainer) {
      annotationsContainer.addEventListener("click", (e) => {
        const btn = e.target.closest(".delete-annotation");
        if (!btn) return;
        const id = parseInt(btn.dataset.id);
        console.log("Delete clicked for annotation id:", id);
        channel.push("delete_annotation", { id })
          .receive("ok", () => {
            console.log("Deleted annotation", id);
            const el = document.querySelector(`.annotation[data-id="${id}"]`);
            if (el) el.remove();
          })
          .receive("error", (e) => console.error("Failed to delete:", e));
      });
    }

    // Set up YouTube player to track current time
    const iframeId = element.dataset.playerId || "video-player";
    onYTReady(() => {
      this.player = new YT.Player(iframeId, {
        events: {
          onReady: () => console.log("YT player ready"),
        }
      });
    });

    const form = document.getElementById("annotation-form");
    if (form) {
      form.addEventListener("submit", (e) => {
        e.preventDefault();
        const body = document.getElementById("annotation-body").value;

        let at = 0;
        if (this.player && typeof this.player.getCurrentTime === "function") {
          at = Math.floor(this.player.getCurrentTime() * 1000);
        }
        document.getElementById("annotation-at").value = at;

        if (body.trim()) {
          channel.push("new_annotation", { body, at })
            .receive("ok", (annotation) => {
              document.getElementById("annotation-body").value = "";
              Video.renderAnnotation(annotation, currentUserId, channel);
            })
            .receive("error", (e) => {
              console.error("Failed to post annotation", e);
            });
        }
      });
    }
  },

  renderAnnotation(annotation, currentUserId, channel) {
    const container = document.getElementById("annotations");
    const noAnnotations = document.getElementById("no-annotations");

    if (noAnnotations) noAnnotations.remove();

    const isOwner = currentUserId && annotation.user.id === currentUserId;

    const div = document.createElement("div");
    div.className = "annotation p-4 bg-white/[0.03] border border-white/[0.1] backdrop-blur-md rounded-lg";
    div.dataset.id = annotation.id;
    div.dataset.at = annotation.at;
    div.innerHTML = `
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2">
          <span class="text-xs font-mono text-indigo-400 bg-indigo-500/10 px-2 py-1 rounded">
            ${this.formatTime(annotation.at)}
          </span>
          <span class="font-semibold text-slate-50">${annotation.user.username}</span>
        </div>
        ${isOwner ? `
          <button class="delete-annotation text-slate-400 hover:text-red-500 transition-colors" data-id="${annotation.id}" title="Delete annotation">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd" />
            </svg>
          </button>
        ` : ""}
      </div>
      <p class="mt-2 text-slate-300">${annotation.body}</p>
    `;

    if (isOwner) {
      div.querySelector(".delete-annotation").addEventListener("click", () => {
        channel.push("delete_annotation", { id: annotation.id })
          .receive("ok", () => div.remove())
          .receive("error", (e) => console.error("Failed to delete", e));
      });
    }

    container.appendChild(div);
    div.scrollIntoView({ behavior: "smooth" });
  },

  formatTime(ms) {
    const totalSeconds = Math.floor(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  }
};

const Hooks = {
  VideoPlayer: {
    mounted() {
      const userToken = this.el.dataset.userToken;
      if (userToken) {
        const videoSocket = new Socket("/socket", { params: { token: userToken } });
        videoSocket.connect();
        Video.init(videoSocket, this.el);
      }
    }
  },

  RoomVideoPlayer: {
    mounted() {
      const userToken = this.el.dataset.userToken;
      if (userToken) {
        const roomSocket = new Socket("/socket", { params: { token: userToken } });
        roomSocket.connect();
        Room.init(roomSocket, this.el);
      }
    }
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { ...colocatedHooks, ...Hooks },
})

topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

liveSocket.connect()
window.liveSocket = liveSocket

if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    reloader.enableServerLogs()

    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

// ============================================================
// Room: synchronized watch party
// ============================================================
const Room = {
  player: null,
  channel: null,
  isHost: false,

  init(socket, el) {
    const roomCode = el.dataset.roomCode;
    const isHost = el.dataset.isHost === "true";
    this.isHost = isHost;

    this.channel = socket.channel(`room:${roomCode}`, {});

    // Playback sync from host
    this.channel.on("playback", ({ action, time }) => {
      if (!this.player) return;
      this.player.seekTo(time, true);
      if (action === "play") this.player.playVideo();
      if (action === "pause") this.player.pauseVideo();
    });

    // Another guest joined — host sends current state
    this.channel.on("sync_requested", () => {
      if (!this.isHost || !this.player) return;
      const time = this.player.getCurrentTime();
      const paused = this.player.getPlayerState() !== YT.PlayerState.PLAYING;
      this.channel.push("sync_response", { time, paused });
    });

    // Chat message received
    this.channel.on("chat_message", (msg) => {
      this.appendChatMessage(msg.user.username, msg.body);
    });

    // Room closed by host
    this.channel.on("room_closed", () => {
      document.getElementById("room-closed-overlay")?.classList.remove("hidden");
    });

    this.channel.join()
      .receive("ok", () => {
        console.log("Joined room:", roomCode);
        // If guest, request sync
        if (!isHost) {
          this.channel.push("request_sync", {});
        }
      })
      .receive("error", (e) => console.error("Room join failed", e));

    // Init YouTube player
    const iframeId = "room-player";
    onYTReady(() => {
      this.player = new YT.Player(iframeId, {
        events: {
          onReady: () => console.log("Room YT player ready"),
          onStateChange: (e) => {
            // Host broadcasts state changes
            if (!isHost) return;
            const time = this.player.getCurrentTime();
            if (e.data === YT.PlayerState.PLAYING) {
              this.channel.push("playback", { action: "play", time });
            } else if (e.data === YT.PlayerState.PAUSED) {
              this.channel.push("playback", { action: "pause", time });
            }
          }
        }
      });
    });

    // Host manual controls
    document.getElementById("btn-play")?.addEventListener("click", () => {
      const time = this.player?.getCurrentTime() || 0;
      this.player?.playVideo();
      this.channel.push("playback", { action: "play", time });
    });

    document.getElementById("btn-pause")?.addEventListener("click", () => {
      const time = this.player?.getCurrentTime() || 0;
      this.player?.pauseVideo();
      this.channel.push("playback", { action: "pause", time });
    });

    document.getElementById("btn-seek")?.addEventListener("click", () => {
      const secs = parseFloat(document.getElementById("seek-input")?.value || 0);
      this.player?.seekTo(secs, true);
      this.channel.push("playback", { action: "play", time: secs });
    });

    // End room button
    document.getElementById("close-room-btn")?.addEventListener("click", () => {
      if (confirm("End the room for everyone?")) {
        this.channel.push("close_room", {});
        window.location.href = "/videos";
      }
    });

    // Chat
    const chatInput = document.getElementById("chat-input");
    const chatSend = document.getElementById("chat-send");

    const sendChat = () => {
      const body = chatInput?.value?.trim();
      if (body) {
        this.channel.push("chat_message", { body });
        chatInput.value = "";
      }
    };

    chatSend?.addEventListener("click", sendChat);
    chatInput?.addEventListener("keydown", (e) => {
      if (e.key === "Enter") sendChat();
    });
  },

  appendChatMessage(username, body) {
    const container = document.getElementById("chat-messages");
    document.getElementById("chat-empty")?.remove();

    const div = document.createElement("div");
    div.className = "flex flex-col gap-0.5";
    div.innerHTML = `
      <span class="text-xs font-semibold text-indigo-400">${username}</span>
      <p class="text-sm text-white/80 leading-relaxed break-words">${body}</p>
    `;
    container.appendChild(div);
    container.scrollTop = container.scrollHeight;
  }
};
