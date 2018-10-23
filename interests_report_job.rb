require 'rufus-scheduler'
require 'logger'
require_relative 'interests_report_maker'

scheduler = Rufus::Scheduler.new

scheduler.cron '5 * * * *' do
  logger = Logger.new(STDOUT)
  logger.debug('starting interests report')
  report_maker = InterestsReportMaker.new
  report_maker.update_reports
end

scheduler.join
