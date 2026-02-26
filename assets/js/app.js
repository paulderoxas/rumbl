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
    div.className = "annotation p-3 bg-gray-50 rounded-lg";
    div.dataset.id = annotation.id;
    div.dataset.at = annotation.at;
    div.innerHTML = `
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2">
          <span class="text-xs font-mono text-brand bg-brand/10 px-2 py-1 rounded">
            ${this.formatTime(annotation.at)}
          </span>
          <span class="font-semibold text-gray-800">${annotation.user.username}</span>
        </div>
        ${isOwner ? `
          <button class="delete-annotation text-gray-400 hover:text-red-500 transition-colors" data-id="${annotation.id}" title="Delete annotation">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd" />
            </svg>
          </button>
        ` : ""}
      </div>
      <p class="mt-1 text-gray-600">${annotation.body}</p>
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
