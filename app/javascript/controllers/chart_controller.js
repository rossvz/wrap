import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { data: Object }

  async connect() {
    const { Chart } = await import("chart.js/auto")

    this.chart = new Chart(this.canvasTarget, {
      type: "bar",
      data: this.dataValue,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: { y: { beginAtZero: true } }
      }
    })
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }
}
