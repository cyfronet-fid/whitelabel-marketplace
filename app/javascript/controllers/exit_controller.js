import { Controller } from "@hotwired/stimulus";
import { Turbo } from "@hotwired/turbo-rails";

export default class extends Controller {
  static targets = ["modal", "modalNameInput", "formNameInput"];

  connect() {}

  showModal(event) {
    event.preventDefault();
    this.modalTarget.classList.remove("d-none");
    this.modalNameInputTarget.value = this.formNameInputTarget.value;
  }

  recirectToProvider(event) {
    Turbo.visit(`/backoffice/providers/${event.target.dataset.providerId}`);
  }

  redirectToExtendedForm(event) {
    Turbo.visit(`/backoffice/providers/${event.target.dataset.providerId}/edit?step=classification`);
  }
}
