import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    data: Object,
    type: { type: String, default: "bar" }
  }

  #isConnected = false
  #chart = null

  async connect() {
    this.#isConnected = true

    const { Chart } = await import("chart.js/auto")

    if (!this.#isConnected || !this.element.isConnected) return

    this.#chart = new Chart(this.canvasTarget, {
      type: this.typeValue,
      data: this.dataValue,
      options: this.chartOptions
    })
  }

  disconnect() {
    this.#isConnected = false
    if (this.#chart) {
      this.#chart.destroy()
      this.#chart = null
    }
  }

  dataValueChanged() {
    if (this.#chart && this.element.isConnected) {
      this.#chart.data = this.dataValue
      this.#chart.update("none")
    }
  }

  get chartOptions() {
    const baseOptions = {
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 0 },
      plugins: {
        legend: { display: this.typeValue === "doughnut" }
      }
    }

    if (this.typeValue === "bar" || this.typeValue === "line") {
      baseOptions.scales = { y: { beginAtZero: true } }
    }

    if (this.typeValue === "doughnut") {
      baseOptions.cutout = "60%"
    }

    return baseOptions
  }
}
