import { CategoryFactory } from "cypress/factories/category.factory";
import { UserFactory } from "../../../../factories/user.factory";
import { CategoryMessages } from "../../../../fixtures/messages";

describe("Category", () => {
  const user = UserFactory.create({roles: ["service_portfolio_manager"]});
  const [category, category1, category2, category3,category4] = [...Array(5)].map(()=> CategoryFactory.create())
  const message = CategoryMessages;

  const correctLogo = "logo.jpg"
  const wrongLogo = "logo.svg"
  
  beforeEach(() => {
    cy.visit("/");
    cy.loginAs(user);
    
  });
  
  it("should create new category without parent", () => {
    // cy.get("[data-e2e='my-eosc-button']")
    //   .click();
    // cy.get("[data-e2e='backoffice']")
    //   .click();
    cy.visit("/backoffice")
    cy.location("href")
      .should("contain", "/backoffice");
    cy.get("[data-e2e='categories']")
      .click();
    cy.location("href")
      .should("contain", "backoffice/categories");
    cy.get("[data-e2e='add-new-category']")   
      .click();
    cy.fillFormCreateCategory(category, correctLogo);
    cy.get("[data-e2e='create-category-btn']")
      .click();
    cy.contains("div.alert-success", message.successCreationMessage)
  });

  it("should create new category with parent", () => {
    cy.visit("/backoffice/categories/new")
    cy.fillFormCreateCategory({...category1, parent: "Sharing & Discovery"}, correctLogo);
    cy.get("[data-e2e='create-category-btn']")
      .click();
    cy.get("h1")
      .invoke("text")
      .then(value=>{
        cy.location("href")
          .should("contain", `/backoffice/categories/${value}`);
        cy.visit("/services")
        cy.get("[data-e2e='categories-list'] a").contains("Sharing & Discovery").click()
        cy.location("href")
          .should("contain", `services/c/sharing-discovery`);
        cy.get("[data-e2e='sub-categories-list']").should("be.visible").find("li").contains(value).click()
        cy.location("href")
          .should("contain", `services/c/${value}`);  
    });
  });

  it("should add new category without logo", () => {
    cy.visit("/backoffice/categories/new")
    cy.fillFormCreateCategory(category2, false);
    cy.get("[data-e2e='create-category-btn']")
      .click();
    cy.contains("div.alert-success", message.successCreationMessage)

  });

  it("shouldn't create new category", () => {
    cy.visit("/backoffice/categories/new")
    cy.fillFormCreateCategory({...category3, name:""}, wrongLogo);
    cy.get("[data-e2e='create-category-btn']")
      .click();
    cy.contains("div.invalid-feedback", message.alertLogoValidation)
      .should("be.visible");
    cy.contains("div.invalid-feedback", message.alertNameValidation)
      .should("be.visible");
  });

  it("shouldn't delete category with successors connected to it", () => {
    cy.visit("/backoffice/categories");
    cy.get("[data-e2e='backoffice-categories-list'] li")
      .eq(0)
      .find("a.delete-icon")
      .click();
    cy.contains(".alert-danger", message.alertDeletionMessageSuccessors)
      .should("be.visible");
  });

  it("shouldn't delete category with resource connected to it", () => {
    cy.visit("/backoffice/categories");
    cy.get("[data-e2e='backoffice-categories-list'] li")
      .eq(2)
      .find("a.delete-icon")
      .click();
    cy.contains(".alert-danger", message.alertDeletionMessageResource)
      .should("be.visible");
  });

  it("should delete category without resources", () => {
    cy.visit("/backoffice/categories/new");
    cy.fillFormCreateCategory(category4, correctLogo);
    cy.get("[data-e2e='create-category-btn']")
      .click();
    cy.get("h1")
      .invoke("text")
      .then(value=>{
        cy.visit("/backoffice/categories");
        cy.contains(value)
          .parent()
          .find("a.delete-icon")
          .click();
        cy.contains(".alert-success", message.successDeletionMessage)
          .should("be.visible");
    });
  })

  it("should edit category", () => {
    cy.visit("/backoffice/categories")
    cy.get("[data-e2e='backoffice-categories-list'] li")
      .eq(0)
      .find("a")
      .contains("Edit")
      .click();
    cy.fillFormCreateCategory({description:"Edited category"}, false);
    cy.get("[data-e2e='create-category-btn']")
      .click();
    cy.contains(".alert-success", message.successUpdationMessage )
    cy.contains("p", "Edited category")
      .should("be.visible");
  });
});
