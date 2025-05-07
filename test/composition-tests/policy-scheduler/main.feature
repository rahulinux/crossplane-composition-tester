# Copyright 2023 Swisscom (Schweiz) AG

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

@PolicyScheduler
Feature: Policy scheduler composition
  Tests the policy scheduler composition

  Background:
    Given input claim xr.yaml
    # following step is optional: default input composition is composition.yaml 
    And input composition composition.yaml
    # following step is optional: default input functions is functions.yaml
    And input functions functions.yaml
    Then check that no resources are provisioning

  @critical
  Scenario: create role within the scheduled window

    # render 1
    Given input claim is changed with parameters
      | param name                      | param value          |
      | spec.schedules[0].scheduleFrom  | 2025-01-01T00:00:00Z |
      | spec.schedules[0].scheduleUntil | 2025-12-31T00:00:00Z |
      | spec.schedules[1].scheduleFrom  | 2025-01-01T00:00:00Z |
      | spec.schedules[1].scheduleUntil | 2025-12-31T00:00:00Z |
    When crossplane renders the composition
    Then check that 2 resources are provisioning
      | resource-name    |
      | role-app-1-rpa   |
      | role-app-2-rpa   |

    # render 2
    Given change following observed resources with status READY
      | resource-name  |
      | role-app-1     |
      | role-app-2     |
    When crossplane renders the composition
    Then check that 4 resources are provisioning and they are
      | resource-name  |
      | role-app-1     |
      | role-app-2     |
      | role-app-1-rpa |
      | role-app-2-rpa |
    And check that resource role-app-1-rpa has parameters
      | param name                 | param value |
      | spec.forProvider.roleName  | role-app-1  |
      | spec.forProvider.policyArn | arn:aws:iam::aws:policy/AmazonPolicy1  |
    And check that resource role-app-2-rpa has parameters
      | param name                 | param value |
      | spec.forProvider.roleName  | role-app-2  |
      | spec.forProvider.policyArn | arn:aws:iam::aws:policy/AmazonPolicy2  |

  @critial
  Scenario: prevent creating role outside schedule window

    Given input claim is changed with parameters
      | param name                      | param value          |
      | spec.schedules[0].scheduleFrom  | 2024-01-01T00:00:00Z |
      | spec.schedules[0].scheduleUntil | 2024-12-31T00:00:00Z |
      | spec.schedules[1].scheduleFrom  | 2024-01-01T00:00:00Z |
      | spec.schedules[1].scheduleUntil | 2024-12-31T00:00:00Z |
    When crossplane renders the composition
    Then check that no resources are provisioning

  @critial
  Scenario: do not allow role creation when the schedule start time is after the end time
   Given input claim is changed with parameters
     | param name                      | param value          |
     | spec.schedules[0].scheduleFrom  | 2031-01-01T00:00:00Z |
     | spec.schedules[0].scheduleUntil | 2024-12-31T00:00:00Z |
     | spec.schedules[1].scheduleFrom  | 2031-01-01T00:00:00Z |
     | spec.schedules[1].scheduleUntil | 2024-12-31T00:00:00Z |
   And input composition composition.yaml
   When crossplane renders the composition
   Then check that no resources are provisioning

  @critial
  Scenario: role should not be created when date-time formatting is invalid
   Given input claim is changed with parameters
     | param name                      | param value          |
     | spec.schedules[0].scheduleFrom  | 2031-13-01T00:00:00Z |
   Then rendering fails with error message containing "month out of range"

   Given input claim is changed with parameters
     | param name                      | param value          |
     | spec.schedules[0].scheduleFrom  | 2031-12-32T00:00:00Z |
   Then rendering fails with error message containing "day out of range"

   Given input claim is changed with parameters
     | param name                      | param value      |
     | spec.schedules[0].scheduleFrom  | 2031-12-01T00:00 |
   Then rendering fails with error message containing "cannot parse"

   Given input claim is changed with parameters
     | param name                      | param value          |
     | spec.schedules[0].scheduleFrom  | 01-01-2025T00:00:00Z |
   Then rendering fails with error message containing "error calling mustToDate"
