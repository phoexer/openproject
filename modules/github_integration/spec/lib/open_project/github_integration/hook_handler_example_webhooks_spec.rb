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

# rubocop:disable RSpec/ExampleLength
require File.expand_path('../../../spec_helper', __dir__)

describe OpenProject::GithubIntegration::HookHandler do
  before do
    allow(Setting).to receive(:host_name).and_return('example.net')
  end

  let(:user) { FactoryBot.create(:user) }
  let(:role) do
    FactoryBot.create(:role,
                      permissions: %i[view_work_packages add_work_package_notes])
  end
  let(:statuses) { (1..5).map { |_i| FactoryBot.create(:status) } }
  let(:priority) { FactoryBot.create :priority, is_default: true }
  let(:status) { statuses[0] }
  let(:project) do
    FactoryBot.create(:project).tap do |p|
      p.add_member(user, role).save
    end
  end
  let(:project_without_permission) { FactoryBot.create(:project) }
  let(:wp1) do
    FactoryBot.create :work_package, project: project
  end
  let(:wp2) do
    FactoryBot.create :work_package, project: project
  end
  let(:wp3) do
    FactoryBot.create :work_package,
                      project: project_without_permission
  end
  let(:wp4) do
    FactoryBot.create :work_package,
                      project: project_without_permission
  end
  let(:wps) { [wp1, wp2, wp3, wp4] }

  context 'when receiving a pull request webhook' do
    let(:environment) do
      {
        'HTTP_X_GITHUB_EVENT' => 'pull_request',
        'HTTP_X_GITHUB_DELIVERY' => 'test delivery'
      }
    end

    it "handles the pull_request creation payload" do
      params = ActionController::Parameters.new(
        payload: {
          'action' => 'opened',
          'number' => '5',
          'pull_request' => {
            'title' => 'Bugfixes',
            'body' => "Fixes http://example.net/wp/#{wp1.id} and " +
                      "https://example.net/work_packages/#{wp2.id} and " +
                      "http://example.net/subdir/wp/#{wp3.id} and " +
                      "https://example.net/subdir/work_packages/#{wp4.id}.",
            'html_url' => 'http://pull.request',
            'base' => {
              'repo' => {
                'full_name' => 'full/name',
                'html_url' => 'http://pull.request'
              }
            }
          },
          'sender' => {
            'login' => 'github_login',
            'html_url' => 'http://user.name'
          },
          'repository' => {}
        }
      )

      journal_count = wps.map { |wp| wp.journals.count }
      described_class.new.process('github', OpenStruct.new(env: environment), params, user)

      [wp1, wp2, wp3, wp4].map(&:reload)

      expect(wp1.journals.count).to equal(journal_count[0] + 1)
      expect(wp2.journals.count).to equal(journal_count[1] + 1)
      expect(wp3.journals.count).to equal(journal_count[2] + 0)
      expect(wp4.journals.count).to equal(journal_count[3] + 0)

      expect(wp1.journals.last.notes).to include('PR Opened')
    end

    it "handles the pull_request close payload" do
      params = ActionController::Parameters.new(
        payload: {
          'action' => 'closed',
          'number' => '5',
          'pull_request' => {
            'title' => 'Bugfixes',
            'body' => "Fixes http://example.net/wp/#{wp1.id} and " +
                      "https://example.net/work_packages/#{wp2.id} and " +
                      "http://example.net/subdir/wp/#{wp3.id} and " +
                      "https://example.net/subdir/work_packages/#{wp4.id}.",
            'html_url' => 'http://pull.request',
            'base' => {
              'repo' => {
                'full_name' => 'full/name',
                'html_url' => 'http://pull.request'
              }
            }
          },
          'sender' => {
            'login' => 'github_login',
            'html_url' => 'http://user.name'
          },
          'repository' => {}
        }
      )

      journal_count = wps.map { |wp| wp.journals.count }
      described_class.new.process('github', OpenStruct.new(env: environment), params, user)

      [wp1, wp2, wp3, wp4].map(&:reload)

      expect(wp1.journals.count).to eq(journal_count[0] + 1)
      expect(wp2.journals.count).to eq(journal_count[1] + 1)
      expect(wp3.journals.count).to eq(journal_count[2] + 0)
      expect(wp4.journals.count).to eq(journal_count[3] + 0)

      expect(wp1.journals.last.notes).to include('PR Closed')
    end

    it "handles the pull_request merged payload" do
      params = ActionController::Parameters.new(
        payload: {
          'action' => 'closed',
          'number' => '5',
          'pull_request' => {
            'title' => 'Bugfixes',
            'body' => "Fixes http://example.net/wp/#{wp1.id} and " +
                      "https://example.net/work_packages/#{wp2.id} and " +
                      "http://example.net/subdir/wp/#{wp3.id} and " +
                      "https://example.net/subdir/work_packages/#{wp4.id}.",
            'html_url' => 'http://pull.request',
            'base' => {
              'repo' => {
                'full_name' => 'full/name',
                'html_url' => 'http://pull.request'
              }
            },
            'merged' => true
          },
          'sender' => {
            'login' => 'github_login',
            'html_url' => 'http://user.name'
          },
          'repository' => {}
        }
      )

      journal_count = wps.map { |wp| wp.journals.count }
      described_class.new.process('github', OpenStruct.new(env: environment), params, user)

      [wp1, wp2, wp3, wp4].map(&:reload)

      expect(wp1.journals.count).to equal(journal_count[0] + 1)
      expect(wp2.journals.count).to equal(journal_count[1] + 1)
      expect(wp3.journals.count).to equal(journal_count[2] + 0)
      expect(wp4.journals.count).to equal(journal_count[3] + 0)

      expect(wp1.journals.last.notes).to include('PR Merged')
    end
  end

  context 'when receiving an issue_comment webhook' do
    let(:environment) do
      {
        'HTTP_X_GITHUB_EVENT' => 'issue_comment',
        'HTTP_X_GITHUB_DELIVERY' => 'test delivery'
      }
    end

    it "handles the pull_request comment creation payload" do
      params = ActionController::Parameters.new(
        payload: {
          'action' => 'created',
          'issue' => {
            'title' => 'Bugfixes',
            'number' => '5',
            'pull_request' => {
              'html_url' => 'http://pull.request'
            }
          },
          'comment' => {
            'body' => "Fixes http://example.net/wp/#{wp1.id} and " +
                      "https://example.net/work_packages/#{wp2.id} and " +
                      "http://example.net/subdir/wp/#{wp3.id} and " +
                      "https://example.net/subdir/work_packages/#{wp4.id}.",
            'html_url' => 'http://comment.url',
            'user' => {
              'login' => 'github_login',
              'html_url' => 'http://user.name'
            }
          },
          'sender' => {
          },
          'repository' => {
            'full_name' => 'full/name',
            'html_url' => 'http://pull.request'
          }
        }
      )

      journal_count = wps.map { |wp| wp.journals.count }
      described_class.new.process('github', OpenStruct.new(env: environment), params, user)

      [wp1, wp2, wp3, wp4].map(&:reload)

      expect(wp1.journals.count).to equal(journal_count[0] + 1)
      expect(wp2.journals.count).to equal(journal_count[1] + 1)
      expect(wp3.journals.count).to equal(journal_count[2] + 0)
      expect(wp4.journals.count).to equal(journal_count[3] + 0)

      expect(wp1.journals.last.notes).to include('Referenced')
    end
  end
end
# rubocop:enable RSpec/ExampleLength
