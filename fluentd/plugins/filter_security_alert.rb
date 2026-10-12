require "fluent/plugin/filter"
require "time"

module Fluent
  module Plugin
    # Keeps the Teleport audit events listed in EVENTS, turns each one into a
    # Slack message, and drops everything else.
    class SecurityAlertFilter < Filter
      Fluent::Plugin.register_filter("security_alert", self)

      # Audit event => Slack title. A new event must also be added to `types`
      # in teleport/event-handler.toml.tftpl. Failed events are looked up with
      # " failed" appended, so successful logins and connections do not alert.
      EVENTS = {
        "user.login failed" => "Login failed",
        "db.session.start failed" => "Database connection denied",
        "mfa.add" => "MFA device added",
        "mfa.delete" => "MFA device removed",
        "role.created" => "Role created",
        "role.updated" => "Role updated",
        "role.deleted" => "Role deleted",
        "user.create" => "User created",
        "user.update" => "User updated",
        "user.delete" => "User deleted",
        "access_list.create" => "Access list created",
        "access_list.update" => "Access list updated",
        "access_list.delete" => "Access list deleted",
        "access_list.member.create" => "Access list member added",
        "access_list.member.update" => "Access list member updated",
        "access_list.member.delete" => "Access list member removed",
      }.freeze

      REASON_LIMIT = 300

      def filter(_tag, _time, record)
        name = record["event"].to_s
        name += " failed" if record["success"] == false
        title = EVENTS[name]
        return nil unless title

        fields = [["Event", title], ["User", actor(record)]]
        fields += details(record)
        fields << ["Time", local_time(record["time"])]
        # The same id finds the full event in the Teleport audit log.
        fields << ["Event ID", record["uid"]]

        text = fields
          .reject { |_label, value| value.to_s.empty? }
          .map { |label, value| "*#{label}:* #{escape(value)}" }
          .join("\n")

        # uid is kept for the once filter.
        { "uid" => record["uid"], "text" => text }
      end

      private

      # Access list events name the actor in updated_by instead of user.
      def actor(record)
        user = record["user"].to_s
        user.empty? ? record["updated_by"] : user
      end

      def details(record)
        case record["event"]
        when "user.login"
          # Teleport records the address and client only for some login failures.
          [["From", remote_ip(record)], ["Client", record["user_agent"]], ["Reason", reason(record)]]
        when "db.session.start"
          [
            ["User database", record["db_user"]],
            ["Database", [record["db_service"], record["db_name"]].reject { |part| part.to_s.empty? }.join(" / ")],
            ["Reason", reason(record)],
          ]
        when /\Amfa\./
          [["Device", device(record)], ["From", remote_ip(record)]]
        when /\Arole\./
          [["Role", record["name"]]]
        when /\Auser\./
          [["Account", record["name"]], ["Roles", Array(record["roles"]).join(", ")]]
        when /\Aaccess_list\.member\./
          members = Array(record["members"]).map { |member| member["member_name"] }.compact
          [["Access list", record["access_list_name"]], ["Member", members.join(", ")]]
        when /\Aaccess_list\./
          [["Access list", record["name"]]]
        else
          []
        end
      end

      def remote_ip(record)
        record["addr.remote"].to_s.sub(/:\d+\z/, "")
      end

      def device(record)
        name = record["mfa_device_name"].to_s
        type = record["mfa_device_type"].to_s
        type.empty? ? name : "#{name} (#{type})"
      end

      def reason(record)
        error = record["error"].to_s
        error.length > REASON_LIMIT ? "#{error[0, REASON_LIMIT]}... (truncated)" : error
      end

      def local_time(value)
        Time.parse(value.to_s).getlocal("+07:00").strftime("%Y-%m-%d %H:%M:%S WIB")
      rescue ArgumentError
        value.to_s
      end

      # A failed login carries whatever user name the caller typed. Escaping
      # keeps that text from becoming a Slack link or an @channel mention.
      def escape(value)
        value.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
      end
    end
  end
end
