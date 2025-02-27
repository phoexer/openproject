#-- encoding: UTF-8

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
require_relative './base_service'

module Sessions
  class InitializeSessionService < BaseService
    class << self
      ##
      # Initializes a new session for the given user.
      # This services provides very little for what it is called,
      # mainly caused due to the many ways a user can login.
      def call(user, session)
        session[:user_id] = user.id
        session[:updated_at] = Time.now

        if drop_old_sessions?
          Rails.logger.info { "Deleting all other sessions for #{user}." }
          ::Sessions::ActiveRecord.for_user(user).delete_all
        end

        ServiceResult.new(success: true, result: session)
      end

      private

      ##
      # We can only drop old sessions if they're stored in the database
      # and enabled by configuration.
      def drop_old_sessions?
        active_record_sessions? && OpenProject::Configuration.drop_old_sessions_on_login?
      end
    end
  end
end
