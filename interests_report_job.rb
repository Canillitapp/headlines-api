require 'rufus-scheduler'
require_relative 'interests_report_maker'

scheduler = Rufus::Scheduler.new

scheduler.cron '5 * * * *' do
  report_maker = InterestsReportMaker.new
  report_maker.update_reports
end

scheduler.join
