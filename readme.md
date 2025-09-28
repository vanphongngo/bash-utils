curl -s https://raw.githubusercontent.com/vanphongngo/bash-utils/master/rbucket-redis-delete-keys.sh | bash -s -- -h 10.50.1.22 -p 9319 -k '
  QC|ZPP|TASK|SCENARIO_EXPIRATION_TRACKER|OB_P1_05_1|240913000004303 
  QC|ZPP|TASK|SCENARIO_EXPIRATION_TRACKER|OB_P1_05_2|240913000004303 
  QC|ZPP|TASK|SCENARIO_EXPIRATION_TRACKER|OB_P1_05_3|240913000004303 
  QC|ZPP|TASK|SCENARIO_EXPIRATION_TRACKER|OB_P1_05_4|240913000004303
';

240913000004303


curl -s https://raw.githubusercontent.com/vanphongngo/bash-utils/master/rbucket-redis-delete-keys.sh | bash -s -- -h 10.50.1.21 -p 9315 -k '
zpp:merchant-v2:loyalty:scheme:qc-24:onboarding-campaign-view-tracker:2058:240913000004303
';



curl -s https://raw.githubusercontent.com/vanphongngo/bash-utils/setup-server/setup.sh | bash