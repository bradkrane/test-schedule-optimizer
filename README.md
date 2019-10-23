# Test Schedule Optimizer
Finds optimal test schedules for full participant coverage over multiple paired-participant tests
## Installation Instructions

1. Install Ruby >= 2.0
1. Install gems: `gem install google-api-client`
1. Clone repo to local machine: `git clone https://github.com/bradkrane/test-schedule-optimizer`
1. Modify config YAML to match your schedule and gsheet values. gsheet_id can be found in the sheet URL.

## Usage Instructions

1. Ensure Update Test Schedule Sheet is upto date. (There are no sanity checks, atm so GIGO)
2. Run script via command line: ruby optimize.rb
    - Follow instructions for first use to establish script API access.
3. Profit

## Example Schedule
[Example Google Sheet Test Schedule](https://docs.google.com/spreadsheets/d/1w5txDRbZTwJMA2BDC5-CSQWKXmfu83RJUHdkDwxrb5g "Example Google Sheet")


Copyright (C) 2019 Brad Krane

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
