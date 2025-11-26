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
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar.cjs"

// Phoenix colocated hooks (optional, set to empty if not installed)
const colocatedHooks = {}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Auto-hide flash messages hook
const AutoHideFlash = {
  mounted() {
    const hideAfter = parseInt(this.el.dataset.hideAfter || "2000", 10)
    
    this.timer = setTimeout(() => {
      // Add fade-out transition
      this.el.style.transition = "opacity 0.3s ease-out, transform 0.3s ease-out"
      this.el.style.opacity = "0"
      this.el.style.transform = "translateY(-10px)"
      
      // Hide after transition completes and trigger clear-flash event
      setTimeout(() => {
        this.el.style.display = "none"
        // Trigger the click event to clear flash (same as user clicking)
        const clickEvent = new MouseEvent("click", {
          bubbles: true,
          cancelable: true
        })
        this.el.dispatchEvent(clickEvent)
      }, 300)
    }, hideAfter)
  },
  
  destroyed() {
    if (this.timer) {
      clearTimeout(this.timer)
    }
  }
}

// Set textarea value hook
const SetTextareaValue = {
  mounted() {
    const value = this.el.dataset.value
    if (value) {
      this.el.value = value
    }
  },

  updated() {
    const value = this.el.dataset.value
    if (value) {
      this.el.value = value
    }
  }
}

// Confirm delete hook
const ConfirmDelete = {
  mounted() {
    this.el.addEventListener('click', (e) => {
      const message = this.el.dataset.confirm || 'Czy na pewno chcesz to zrobić?'
      if (!confirm(message)) {
        e.preventDefault()
        e.stopPropagation()
        return false
      }
    })
  }
}

// Half random mode checkbox hook
const HalfRandomMode = {
  mounted() {
    this.el.addEventListener('change', (e) => {
      const isChecked = e.target.checked
      console.log('Half random mode changed:', isChecked)

      // Send event to LiveView
      this.pushEvent('half_random_mode_changed', { half_random_mode: isChecked ? 'true' : 'false' })
    })
  }
}

// Modal dialog hook - opens/closes dialog element based on show attribute
const ModalDialog = {
  mounted() {
    this.handleShow()
  },

  updated() {
    this.handleShow()
  },

  destroyed() {
    if (this.el.open) {
      this.el.close()
    }
  },

  handleShow() {
    const show = this.el.classList.contains('modal-open')
    if (show && !this.el.open) {
      this.el.showModal()
    } else if (!show && this.el.open) {
      this.el.close()
    }
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {
    ...colocatedHooks,
    AutoHideFlash: AutoHideFlash,
    SetTextareaValue: SetTextareaValue,
    ConfirmDelete: ConfirmDelete,
    HalfRandomMode: HalfRandomMode,
    ModalDialog: ModalDialog
  },
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
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

