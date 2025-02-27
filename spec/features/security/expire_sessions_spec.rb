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

describe 'Expire old user sessions',
         with_config: { session_store: :active_record_store },
         type: :feature do
  shared_let(:admin) { FactoryBot.create :admin }
  let(:admin_password) { 'adminADMIN!' }

  before do
    login_with(admin.login, admin_password)

    # Create a dangling session
    Capybara.current_session.driver.browser.clear_cookies
  end

  describe 'logging in again' do
    context 'with drop_old_sessions enabled', with_config: { drop_old_sessions_on_login: true } do
      it 'destroys the old session' do
        expect(::Sessions::ActiveRecord.count).to eq(1)

        first_session = ::Sessions::ActiveRecord.first
        expect(first_session.user_id).to eq(admin.id)

        # Actually login now
        login_with(admin.login, admin_password)

        expect(::Sessions::ActiveRecord.count).to eq(1)
        second_session = ::Sessions::ActiveRecord.first

        expect(second_session.user_id).to eq(admin.id)
        expect(second_session.session_id).not_to eq(first_session.session_id)
      end
    end

    context 'with drop_old_sessions disabled', with_config: { drop_old_sessions_on_login: false } do
      it 'keeps the old session' do
        # Actually login now
        login_with(admin.login, admin_password)

        expect(::Sessions::ActiveRecord.for_user(admin).count).to eq(2)
      end
    end
  end

  describe 'logging out on another session', with_config: { drop_old_sessions_on_login: false } do
    before do
      # Actually login now
      login_with(admin.login, admin_password)
      expect(::Sessions::ActiveRecord.for_user(admin).count).to eq(2)
      visit '/logout'
    end

    context 'with drop_old_sessions enabled', with_config: { drop_old_sessions_on_logout: true } do
      it 'destroys the old session' do
        # A fresh session is opened due to reset_session
        expect(::Sessions::ActiveRecord.for_user(admin).count).to eq(0)
        expect(::Sessions::ActiveRecord.non_user.count).to eq(1)
      end
    end

    context 'with drop_old_sessions disabled',
            with_config: { drop_old_sessions_on_logout: false } do
      it 'keeps the old session' do
        expect(::Sessions::ActiveRecord.count).to eq(2)
        expect(::Sessions::ActiveRecord.for_user(admin).count).to eq(1)
      end
    end
  end
end
