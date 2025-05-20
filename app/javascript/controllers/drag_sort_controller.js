import { Controller } from "@hotwired/stimulus";
import Sortable from "sortablejs";

export default class extends Controller {
  static values = { url: String };

  connect() {
    if (this.element.children.length > 0) { // Only initialize if there are items to sort
      this.sortable = Sortable.create(this.element, {
        animation: 150,
        ghostClass: "sortable-ghost", // Ensure this class is styled in your CSS
        onEnd: this.onDragEnd.bind(this),
        // SortableJS uses `data-id` on direct children of `this.element` by default for `toArray()`
      });
    }
  }

  onDragEnd(event) {
    const itemIds = this.sortable.toArray();
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content;

    if (!csrfToken) {
      console.error("CSRF token not found. Make sure it's included in your layout via csrf_meta_tags.");
      return;
    }

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
      },
      body: JSON.stringify({ account_ids: itemIds }),
    })
    .then(response => {
      if (!response.ok) {
        response.text().then(text => {
          console.error("Failed to update account order.", { status: response.status, statusText: response.statusText, body: text });
        });
        // Optionally, revert UI or show an error message to the user
      } else {
        console.log("Account order updated successfully.");
        // Optionally, provide success feedback to the user
      }
    })
    .catch(error => {
      console.error("Error updating account order:", error);
      // Optionally, show an error message to the user
    });
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy();
    }
  }
}
