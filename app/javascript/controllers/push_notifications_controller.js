import { Controller } from "@hotwired/stimulus"

// Manages push notification subscription/unsubscription
export default class extends Controller {
  static targets = ["status", "button", "testButton"]
  static values = {
    vapidPublicKey: String,
    subscribeUrl: String,
    unsubscribeUrl: String,
    testUrl: String
  }

  async connect() {
    this.updateStatus()
  }

  async updateStatus() {
    if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
      this.statusTarget.textContent = "Push notifications are not supported in this browser."
      this.buttonTarget.disabled = true
      return
    }

    const permission = Notification.permission

    if (permission === "denied") {
      this.statusTarget.textContent = "Notifications are blocked. Please enable them in your browser settings."
      this.buttonTarget.disabled = true
      return
    }

    const registration = await navigator.serviceWorker.ready
    const subscription = await registration.pushManager.getSubscription()

    if (subscription) {
      this.statusTarget.textContent = "Notifications enabled. You'll receive a reminder at noon."
      this.buttonTarget.textContent = "Disable notifications"
      this.buttonTarget.dataset.action = "click->push-notifications#unsubscribe"
      if (this.hasTestButtonTarget) {
        this.testButtonTarget.classList.remove("hidden")
      }
    } else {
      this.statusTarget.textContent = "Get a daily reminder at noon to log your habits."
      this.buttonTarget.textContent = "Enable notifications"
      this.buttonTarget.dataset.action = "click->push-notifications#subscribe"
      if (this.hasTestButtonTarget) {
        this.testButtonTarget.classList.add("hidden")
      }
    }
  }

  async subscribe() {
    try {
      this.buttonTarget.disabled = true
      this.statusTarget.textContent = "Enabling notifications..."

      // Register service worker if not already
      const registration = await navigator.serviceWorker.register("/service-worker.js")
      await navigator.serviceWorker.ready

      // Request permission
      const permission = await Notification.requestPermission()
      if (permission !== "granted") {
        this.statusTarget.textContent = "Permission denied. Enable notifications in your browser settings."
        this.buttonTarget.disabled = false
        return
      }

      // Subscribe to push
      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.urlBase64ToUint8Array(this.vapidPublicKeyValue)
      })

      // Send subscription to server
      const response = await fetch(this.subscribeUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: JSON.stringify({
          push_subscription: {
            endpoint: subscription.endpoint,
            p256dh_key: btoa(String.fromCharCode(...new Uint8Array(subscription.getKey("p256dh")))),
            auth_key: btoa(String.fromCharCode(...new Uint8Array(subscription.getKey("auth"))))
          }
        })
      })

      if (response.ok) {
        this.updateStatus()
      } else {
        this.statusTarget.textContent = "Failed to enable notifications. Please try again."
      }
    } catch (error) {
      console.error("Push subscription error:", error)
      this.statusTarget.textContent = "An error occurred. Please try again."
    } finally {
      this.buttonTarget.disabled = false
    }
  }

  async unsubscribe() {
    try {
      this.buttonTarget.disabled = true
      this.statusTarget.textContent = "Disabling notifications..."

      const registration = await navigator.serviceWorker.ready
      const subscription = await registration.pushManager.getSubscription()

      if (subscription) {
        // Unsubscribe from push
        await subscription.unsubscribe()

        // Tell server to remove subscription
        await fetch(this.unsubscribeUrlValue, {
          method: "DELETE",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
          },
          body: JSON.stringify({ endpoint: subscription.endpoint })
        })
      }

      this.updateStatus()
    } catch (error) {
      console.error("Push unsubscribe error:", error)
      this.statusTarget.textContent = "An error occurred. Please try again."
    } finally {
      this.buttonTarget.disabled = false
    }
  }

  async test() {
    try {
      this.testButtonTarget.disabled = true
      this.testButtonTarget.textContent = "Sending..."

      await fetch(this.testUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        }
      })

      this.testButtonTarget.textContent = "Test notification"
    } catch (error) {
      console.error("Test notification error:", error)
    } finally {
      this.testButtonTarget.disabled = false
    }
  }

  // Convert base64 VAPID key to Uint8Array
  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const rawData = atob(base64)
    const outputArray = new Uint8Array(rawData.length)
    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i)
    }
    return outputArray
  }
}
