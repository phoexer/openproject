#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2021 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++

require 'spec_helper'

describe 'Projects', type: :feature do
  let(:current_user) { FactoryBot.create(:admin) }

  before do
    allow(User).to receive(:current).and_return current_user
  end

  describe 'creation', js: true do
    shared_let(:project) { FactoryBot.create(:project, name: 'Foo project', identifier: 'foo-project') }

    before do
      visit projects_path
    end

    it 'can create a project' do
      click_on 'New project'

      fill_in 'project[name]', with: 'Foo bar'
      click_on 'Advanced settings'
      fill_in 'project[identifier]', with: 'foo'
      sleep 1

      click_on 'Create'

      expect(page).to have_content 'Successful creation.'
      expect(page).to have_content 'Foo bar'
      expect(current_path).to eq '/projects/foo/work_packages'
    end

    context 'work_packages module disabled',
            with_settings: { default_projects_modules: 'wiki' } do
      it 'creates a project and redirects to settings' do
        click_on 'New project'

        fill_in 'project[name]', with: 'Foo bar'
        click_on 'Advanced settings'
        fill_in 'project[identifier]', with: 'foo'
        sleep 1
        click_on 'Create'

        expect(page).to have_content 'Successful creation.'
        expect(page).to have_content 'Foo bar'
        expect(current_path).to eq '/projects/foo/'
      end
    end

    it 'can create a subproject' do
      click_on 'Foo project'
      SeleniumHubWaiter.wait
      click_on 'Project settings'
      SeleniumHubWaiter.wait
      click_on 'New subproject'

      fill_in 'project[name]', with: 'Foo child'
      click_on 'Create'

      expect(page).to have_content 'Successful creation.'
      expect(current_path).to eq '/projects/foo-child/work_packages'
    end

    it 'does not create a project with an already existing identifier' do
      click_on 'New project'

      fill_in 'project[name]', with: 'Foo project'
      click_on 'Create'

      expect(page).to have_content 'Identifier has already been taken'
      expect(current_path).to eq '/projects'
    end

    context 'with a multi-select custom field' do
      let!(:list_custom_field) { FactoryBot.create(:list_project_custom_field, name: 'List CF', multi_value: true) }

      it 'can create a project' do
        click_on 'New project'

        fill_in 'project[name]', with: 'Foo bar'
        click_on 'Advanced settings'
        fill_in 'project[identifier]', with: 'foo'

        select 'A', from: 'List CF'
        select 'B', from: 'List CF'

        sleep 1

        click_on 'Create'

        expect(page).to have_content 'Successful creation.'
        expect(page).to have_content 'Foo bar'
        expect(current_path).to eq '/projects/foo/work_packages'

        project = Project.last
        expect(project.name).to eq 'Foo bar'
        cvs = project.custom_value_for(list_custom_field)
        expect(cvs.count).to eq 2
        expect(cvs.map(&:typed_value)).to contain_exactly 'A', 'B'
      end
    end
  end

  describe 'project types' do
    let(:phase_type)     { FactoryBot.create(:type, name: 'Phase', is_default: true) }
    let(:milestone_type) { FactoryBot.create(:type, name: 'Milestone', is_default: false) }
    let!(:project) { FactoryBot.create(:project, name: 'Foo project', types: [phase_type, milestone_type]) }

    it "have the correct types checked for the project's types" do
      visit projects_path
      click_on 'Foo project'
      click_on 'Project settings'
      click_on 'Work package types'

      field_checked = find_field('Phase', visible: false)['checked']
      expect(field_checked).to be_truthy
      field_checked = find_field('Milestone', visible: false)['checked']
      expect(field_checked).to be_truthy
    end
  end

  describe 'deletion', js: true do
    let(:project) { FactoryBot.create(:project) }
    let(:projects_page) { Pages::Projects::Destroy.new(project) }

    before do
      projects_page.visit!
    end

    describe 'disable delete w/o confirm' do
      it { expect(page).to have_css('.danger-zone .button[disabled]') }
    end

    describe 'disable delete with wrong input' do
      let(:input) { find('.danger-zone input') }
      it do
        input.set 'Not the project name'
        expect(page).to have_css('.danger-zone .button[disabled]')
      end
    end

    describe 'enable delete with correct input' do
      let(:input) { find('.danger-zone input') }
      it do
        input.set project.name
        expect(page).to have_css('.danger-zone .button:not([disabled])')
      end
    end
  end

  describe 'identifier edit', js: true do
    let!(:project) { FactoryBot.create(:project, identifier: 'foo') }

    it 'updates the project identifier' do
      visit projects_path
      click_on project.name
      SeleniumHubWaiter.wait
      click_on 'Project settings'
      SeleniumHubWaiter.wait
      click_on 'Edit'

      expect(page).to have_content "CHANGE THE PROJECT'S IDENTIFIER"
      expect(current_path).to eq '/projects/foo/identifier'

      fill_in 'project[identifier]', with: 'foo-bar'
      click_on 'Update'

      expect(page).to have_content 'Successful update.'
      expect(current_path).to eq '/projects/foo-bar/settings/generic'
      expect(Project.first.identifier).to eq 'foo-bar'
    end

    it 'displays error messages on invalid input' do
      visit identifier_project_path(project)

      fill_in 'project[identifier]', with: 'FOOO'
      click_on 'Update'

      expect(page).to have_content 'Identifier is invalid.'
      expect(current_path).to eq '/projects/foo/identifier'
    end
  end

  describe 'form', js: true do
    let(:project) { FactoryBot.build(:project, name: 'Foo project', identifier: 'foo-project') }
    let!(:optional_custom_field) do
      FactoryBot.create(:custom_field, name: 'Optional Foo',
                                       type: ProjectCustomField,
                                       is_for_all: true)
    end
    let!(:required_custom_field) do
      FactoryBot.create(:custom_field, name: 'Required Foo',
                                       type: ProjectCustomField,
                                       is_for_all: true,
                                       is_required: true)
    end

    it 'seperates optional and required custom fields for new' do
      visit new_project_path

      expect(page).to have_content 'Required Foo'

      click_on 'Advanced settings'

      within('#advanced-project-settings') do
        expect(page).to have_content 'Optional Foo'
        expect(page).not_to have_content 'Required Foo'
      end
    end

    it 'shows optional and required custom fields for edit without an seperation' do
      project.custom_field_values.last.value = 'FOO'
      project.save!

      visit settings_generic_project_path(project.id)

      expect(page).to have_content 'Required Foo'
      expect(page).to have_content 'Optional Foo'
    end

    context 'with a restricted custom field' do
      let(:project) { FactoryBot.create(:project, name: 'Foo project', identifier: 'foo-project') }
      let!(:required_custom_field) do
        FactoryBot.create(:string_project_custom_field,
                          name: 'Foo',
                          type: ProjectCustomField,
                          min_length: 1,
                          max_length: 2,
                          is_for_all: true)
      end

      it 'shows the errors of that field when saving (Regression #33766)' do
        visit settings_generic_project_path(project.id)

        expect(page).to have_content 'Foo'
        # Enter something too long
        fill_in 'Foo', with: '1234'

        click_on 'Save'
        expect(page).to have_selector('#errorExplanation', text: 'Foo is too long (maximum is 2 characters)')
      end
    end
  end

  context 'with a multi-select custom field' do
    let(:project) { FactoryBot.create(:project, name: 'Foo project', identifier: 'foo-project') }
    let!(:list_custom_field) { FactoryBot.create(:list_project_custom_field, name: 'List CF', multi_value: true) }

    it 'can create a project' do
      visit settings_generic_project_path(project.id)

      select 'A', from: 'List CF'
      select 'B', from: 'List CF'

      sleep 1

      click_on 'Save'

      expect(page).to have_content 'Successful update.'

      expect(page).to have_select('List CF', selected: %w[A B])

      cvs = project.reload.custom_value_for(list_custom_field)
      expect(cvs.count).to eq 2
      expect(cvs.map(&:typed_value)).to contain_exactly 'A', 'B'
    end
  end
end
