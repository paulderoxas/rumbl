import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/rumbl"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Video Channel for Real-time Annotations
const Video = {
  init(socket, element) {
    if (!element) return;

    const videoId = element.dataset.id;
    const channel = socket.channel(`video:${videoId}`, {});

    channel.on("new_annotation", (resp) => {
      this.renderAnnotation(resp);
    });

    channel
      .join()
      .receive("ok", (resp) => {
        console.log("Joined video channel", resp);
      })
      .receive("error", (reason) => {
        console.error("Join failed", reason);
      });

    const form = document.getElementById("annotation-form");
    if (form) {
      form.addEventListener("submit", (e) => {
        e.preventDefault();
        const body = document.getElementById("annotation-body").value;
        const at = parseInt(document.getElementById("annotation-at").value) || 0;

        if (body.trim()) {
          channel.push("new_annotation", { body, at })
            .receive("ok", () => {
              document.getElementById("annotation-body").value = "";
            })
            .receive("error", (e) => {
              console.error("Failed to post annotation", e);
            });
        }
      });
    }
  },

  renderAnnotation(annotation) {
    const container = document.getElementById("annotations");
    const noAnnotations = document.getElementById("no-annotations");

    if (noAnnotations) noAnnotations.remove();

    const div = document.createElement("div");
    div.className = "annotation p-3 bg-gray-50 rounded-lg";
    div.dataset.at = annotation.at;
    div.innerHTML = `
      <div class="flex items-center gap-2">
        <span class="text-xs font-mono text-brand bg-brand/10 px-2 py-1 rounded">
          ${this.formatTime(annotation.at)}
        </span>
        <span class="font-semibold text-gray-800">${annotation.user.username}</span>
      </div>
      <p class="mt-1 text-gray-600">${annotation.body}</p>
    `;
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
