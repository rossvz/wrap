// Service worker for Wrap - handles push notifications

self.addEventListener("push", async (event) => {
  try {
    const data = await event.data.json()
    const title = data.title
    const options = data.options || {}
    event.waitUntil(self.registration.showNotification(title, options))
  } catch (error) {
    console.error("Push notification error:", error)
  }
})

self.addEventListener("notificationclick", function(event) {
  event.notification.close()
  event.waitUntil(
    clients.matchAll({ type: "window" }).then((clientList) => {
      for (let i = 0; i < clientList.length; i++) {
        let client = clientList[i]
        let clientPath = (new URL(client.url)).pathname

        if (clientPath == event.notification.data.path && "focus" in client) {
          return client.focus()
        }
      }

      if (clients.openWindow) {
        return clients.openWindow(event.notification.data.path)
      }
    })
  )
})
