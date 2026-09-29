# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tasks::ImportAllJob, backend: true do
  let(:import_all_task) { instance_double(Rake::Task, invoke: true) }

  before do
    allow(Rails.application).to receive(:load_tasks)
    allow(Rake::Task).to receive(:[]).with("import:all").and_return(import_all_task)
  end

  it "runs on the imports queue" do
    expect(described_class.new.queue_name).to eq("imports")
  end

  context "when performed" do
    before { described_class.perform_now }

    it "loads the application's rake tasks" do
      expect(Rails.application).to have_received(:load_tasks)
    end

    it "invokes the import:all rake task" do
      expect(import_all_task).to have_received(:invoke)
    end
  end
end
