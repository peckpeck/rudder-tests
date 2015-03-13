#!/bin/bash

PF=debian
RULE_ID=F54433C9-9951-4347-B36C-FD43DB0B34CD
TEST_NAME=newtest

RULE_FILE="spec/tests/${TEST_NAME}_rule.rb"
TEST_FILE="spec/tests/${TEST_NAME}_test.rb"
SCENARIO_FILE="scenario/${TEST_NAME}.py"

shopt -s expand_aliases
. <(./rtf scenario env ${PF})

rule=$(rcli rule show ${RULE_ID})

name=$(echo "${rule}" | jq ".rules[0].displayName")
longdesc=$(echo "${rule}" | jq ".rules[0].longDescription")
shortdesc=$(echo "${rule}" | jq ".rules[0].shortDescription")
directives=$(echo "${rule}" | jq ".rules[0].directives[]" | sed -e 's/"//g')

cat > ${RULE_FILE} <<BASH_EOF
require 'spec_helper'

group = \$params['GROUP']
name = \$params['NAME']

directiveFile = "/tmp/directive.json"
ruleFile = "/tmp/rule.json"

describe "Add a test directive and a rule"  do

BASH_EOF

id=1
for directive_id in ${directives}
do
  directive=$(rcli directive show ${directive_id} | jq ".directives[0]")
  name=$(echo "${directive}" | jq ".displayName")
  technique=$(echo "${directive}" | jq ".techniqueName")

cat >> ${RULE_FILE} <<BASH_EOF
  # Add directive
  describe command(\$rudderCli + " directive create --json=" + directiveFile + " ${technique} ${name}") do
    before(:all) {
      File.open(directiveFile, 'w') { |file|
        file << <<EOF
${directive}
EOF
      }
    }
    after(:all) {
      File.delete(directiveFile)
    }
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match /^"[0-9a-f\\-]+"$/ }
    it {
      # register output uuid for next command
      \$uuid${id} = subject.stdout.gsub(/^"|"$/, "").chomp()
    }
  end

BASH_EOF
  id=$((id+1))
done

cat >> ${RULE_FILE} <<BASH_EOF
  # create a rule
  describe command(i\$rudderCli + " rule create --json=" + ruleFile + " testRule") do
    before(:all) {
      File.open(ruleFile, 'w') { |file|
        file << <<EOF
{
  "directives": [
BASH_EOF

last_id=$((id-1))
prev_id=$((id-2))
for i in $(seq 1 ${prev_id})
do
  echo "    \"#{\$uuid${i}}\"," >> ${RULE_FILE}
done
echo "    \"#{\$uuid${last_id}}\"" >> ${RULE_FILE}

cat >> ${RULE_FILE} <<BASH_EOF
  ],
  "displayName": "#{name} Rule",
  "longDescription": "Test ${TEST_NAME} ",
  "shortDescription": "Test ${TEST_NAME}",
  "targets": [
    {
      "exclude": {
        "or": []
      },
      "include": {
        "or": [
          "#{group}"
        ]
      }
    }
  ]
}
EOF
      }
    }
    after(:all) {
      File.delete(ruleFile)
    }
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match /^"[0-9a-f\\-]+"$/ }
    it {
      # register output uuid for next command
      \$uuid = subject.stdout.gsub(/^"|"$/, "").chomp()
    }
  end

end
BASH_EOF


cat > ${TEST_FILE} <<BASH_EOF
require 'spec_helper'

# Please add your test here
# see http://serverspec.org/resource_types.html for a full documentation of available tests

## Ex Test that a user exist
#describe user('testuser') do
#  it { should exist }
#  it { should have_home_directory '/home/testuser' }
#end

## Ex Test that a file exists
#describe file('/etc/passwd') do
#  it { should be_file }
#  it { should be_mode 640 }
#  it { should be_owned_by 'root' }
#  its(:content) { should match /regex to match/ }
#end

## Ex Test the output of a command
#describe command('ls -al /') do
#  its(:stdout) { should match /bin/ }
#  its(:stderr) { should match /No such file or directory/ }
#  its(:exit_status) { should eq 0 }
#end

BASH_EOF

cat > "${SCENARIO_FILE}" <<EOF
from scenario.lib import *

# test begins, register start time
start()

run_on_all('agent', Err.CONTINUE)

# force inventory
run_on_agents('run_agent', Err.CONTINUE, PARAMS="-D force_inventory")
run_on_servers('run_agent', Err.CONTINUE, PARAMS="")

# accept nodes
for host in scenario.agent_nodes():
  run('localhost', 'agent_accept', Err.BREAK, ACCEPT=host)

# Add a rule 
date0 = host_date('wait', Err.CONTINUE, "server")
run('localhost', '${TEST_NAME}_rule', Err.BREAK, NAME="Test ${TEST_NAME}", GROUP="special:all")
for host in scenario.agent_nodes():
  wait_for_generation('wait', Err.CONTINUE, "server", date0, host, 20)

# Run agent
run_on_agents('run_agent', Err.CONTINUE, PARAMS="-f failsafe.cf")
run_on_agents('run_agent', Err.CONTINUE, PARAMS="")

# Test rule result
run_on_agents('${TEST_NAME}_test', Err.CONTINUE)

# remove rule/directive
run('localhost', 'directive_delete', Err.FINALLY, DELETE="Test ${TEST_NAME} Directive", GROUP="special:all")
run('localhost', 'rule_delete', Err.FINALLY, DELETE="Test ${TEST_NAME} Rule", GROUP="special:all")

# remove agent
for host in scenario.agent_nodes():
  run('localhost', 'agent_delete', Err.FINALLY, DELETE=host)

# test end, print summary
finish()
EOF

echo ""
echo "Please edit ${TEST_FILE} to add your checks"
echo ""
echo "I created a scenario with this single test in ${SCENARIO_FILE}"
echo "You can run it with ./rtf scenario run ${TEST_NAME}"
echo ""
echo "You may want to import a part of it in an existing scenario"
echo ""

