describe("Scientific domain", () => {
  beforeEach(() => {
    cy.visit("/");
  });

  it("should go to services page with selected scientific domain", () => {
    cy.intercept("GET", "/services*").as("services");
    cy.get("a[data-e2e='branch-link']")
      .eq(0)
      .click();
    cy.location("href")
      .should("include", "search/service");

  });
  it("should go to services page with selected category", () => {
    cy.intercept("GET", "/categories/*").as("categories");
    cy.get("li")
      .contains("Categories")
      .click();
    cy.get("a[href*='categories'][data-e2e='branch-link']")
      .eq(0)
      .click();
    cy.location("href")
      .should("include", "search");
  });
});