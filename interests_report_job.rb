require 'rufus-scheduler'
require 'logger'
require_relative 'interests_report_maker'

scheduler = Rufus::Scheduler.new

# schedule this at 4:30am and 6:30am everyday
scheduler.cron '30 4,6 * * *' do
  logger = Logger.new(STDOUT)
  logger.debug('starting interests report')
  report_maker = InterestsReportMaker.new
  report_maker.update_reports
end

scheduler.join
