import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="list"
export default class extends Controller {
  static targets = ["name", "checkbox", "btn"];
  connect() {}

  toggleAll(event) {
    const target = event.currentTarget;
    this.checkboxTargets.forEach((el) => (el.checked = target.checked));
  }

  toggleCurrent(event) {
    event.preventDefault();
    const target = document.getElementById(event.currentTarget.dataset.value);
    target.checked = !target.checked;
  }

  toggleActions(event) {
    if (!this.checkboxTargets.some((el) => el.checked)) {
      this.btnTargets.forEach((el) => (el.disabled = true));
    } else {
      this.btnTargets.forEach((el) => (el.disabled = false));
    }
  }
}
