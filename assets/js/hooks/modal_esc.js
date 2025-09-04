export default {
  mounted() {
    this.handleKeydown = (event) => {
      if (event.key === "Escape") {
        event.preventDefault();
        this.el.click();
      }
    };

    document.addEventListener("keydown", this.handleKeydown);
  },

  destroyed() {
    document.removeEventListener("keydown", this.handleKeydown);
  },
};
