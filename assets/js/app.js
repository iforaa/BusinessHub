// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

const Hooks = {
  GoogleSignIn: {
    mounted() {
      const clientId = this.el.dataset.clientId
      const el = this.el

      const init = () => {
        window.google.accounts.id.disableAutoSelect()
        window.google.accounts.id.initialize({
          client_id: clientId,
          auto_select: false,
          cancel_on_tap_outside: true,
          ux_mode: "popup",
          hd: "tenfore.golf",
          callback: (response) => {
            fetch("/auth/google", {
              method: "POST",
              headers: {"Content-Type": "application/json"},
              body: JSON.stringify({credential: response.credential})
            })
              .then(r => r.json())
              .then(data => {
                if (data.success) {
                  window.location.href = "/"
                } else {
                  alert(data.error || "Login failed")
                }
              })
              .catch(() => alert("Login failed"))
          }
        })
        window.google.accounts.id.renderButton(el, {
          theme: "outline",
          size: "large",
          text: "signin_with",
          shape: "rectangular",
          logo_alignment: "left",
          width: 280
        })
      }

      if (window.google && window.google.accounts) {
        init()
      } else {
        const script = document.createElement("script")
        script.src = "https://accounts.google.com/gsi/client"
        script.async = true
        script.defer = true
        script.onload = init
        document.head.appendChild(script)
      }
    }
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Clear search input when server pushes clear-search event
window.addEventListener("phx:clear-search", () => {
  const input = document.getElementById("search-input")
  if (input) input.value = ""
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

