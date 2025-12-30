import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.ensureTimezoneCookie()
  }

  ensureTimezoneCookie() {
    if (!this.supportsTimeZones()) return

    const browserTimeZone = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (!browserTimeZone) return

    const cookieTimeZone = this.readCookie("timezone")
    if (cookieTimeZone === browserTimeZone) return

    this.writeCookie(browserTimeZone)

    if (this.readCookie("timezone") === browserTimeZone) {
      window.location.reload()
    }
  }

  supportsTimeZones() {
    return typeof Intl !== "undefined" &&
      typeof Intl.DateTimeFormat === "function" &&
      typeof Intl.DateTimeFormat().resolvedOptions === "function"
  }

  readCookie(name) {
    const match = document.cookie.match(new RegExp("(?:^|; )" + name + "=([^;]*)"))
    return match ? decodeURIComponent(match[1]) : null
  }

  writeCookie(value) {
    const encoded = encodeURIComponent(value)
    document.cookie = `timezone=${encoded};path=/;max-age=${60 * 60 * 24 * 365}`
  }
}
