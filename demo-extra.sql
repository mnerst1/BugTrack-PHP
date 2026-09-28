-- Optional, repeatable demo expansion for an existing BugTrack database.
-- Import after install.sql. Existing users and records are preserved.
USE bugtrack;
SET @admin := (SELECT id FROM users WHERE email='admin@bugtrack.test' LIMIT 1);
SET @manager := (SELECT id FROM users WHERE email='manager@bugtrack.test' LIMIT 1);
SET @member := (SELECT id FROM users WHERE email='member@bugtrack.test' LIMIT 1);

INSERT INTO projects(name,`key`,description,owner_id) VALUES
('Nova Design System','NOVA','Shared components, accessible patterns and product foundations.',@manager),
('Pulse Mobile','PULSE','Mobile experience, performance and release quality.',@admin),
('Meridian Operations','MERID','Internal workflows, reporting and team operations.',@manager)
ON DUPLICATE KEY UPDATE id=id;
SET @nova := (SELECT id FROM projects WHERE `key`='NOVA');
SET @pulse := (SELECT id FROM projects WHERE `key`='PULSE');
SET @merid := (SELECT id FROM projects WHERE `key`='MERID');
SET @atlas := (SELECT id FROM projects WHERE `key`='ATLAS');
SET @orbit := (SELECT id FROM projects WHERE `key`='ORBIT');

INSERT INTO project_members(project_id,user_id,role) VALUES
(@nova,@admin,'manager'),(@nova,@manager,'manager'),(@nova,@member,'member'),
(@pulse,@admin,'manager'),(@pulse,@manager,'manager'),(@pulse,@member,'member'),
(@merid,@admin,'manager'),(@merid,@manager,'manager'),(@merid,@member,'member')
ON DUPLICATE KEY UPDATE user_id=user_id;

INSERT INTO labels(project_id,name,color) VALUES
(@nova,'design','#865bc0'),(@nova,'accessibility','#29917b'),(@nova,'documentation','#5279b9'),
(@pulse,'android','#4d9b72'),(@pulse,'performance','#c27b3c'),(@pulse,'release','#a84d6b'),
(@merid,'workflow','#5279b9'),(@merid,'reporting','#865bc0'),(@merid,'urgent','#c04852'),
(@atlas,'mobile','#4d9b72'),(@orbit,'database','#865bc0')
ON DUPLICATE KEY UPDATE id=id;

INSERT INTO issues(project_id,number,title,description,type,status,priority,reporter_id,assignee_id,due_date) VALUES
(@nova,1,'Audit form controls','Review labels, errors and keyboard order across the shared form components.','task','progress','high',@manager,@member,DATE_ADD(CURDATE(),INTERVAL 4 DAY)),
(@nova,2,'Create compact table variant','Add a dense table layout for data-heavy pages.','feature','todo','medium',@manager,@admin,DATE_ADD(CURDATE(),INTERVAL 11 DAY)),
(@nova,3,'Fix dark mode tooltip contrast','Tooltip text becomes hard to read on dark surfaces.','bug','review','high',@member,@manager,DATE_ADD(CURDATE(),INTERVAL 2 DAY)),
(@nova,4,'Document spacing tokens','Publish examples and usage guidance for spacing tokens.','task','backlog','low',@admin,@member,NULL),
(@nova,5,'Unify empty states','Use consistent text, icons and actions when a list has no content.','task','done','medium',@manager,@admin,NULL),
(@nova,6,'Add focus ring examples','Show accessible focus treatment for every interactive component.','feature','todo','medium',@member,@manager,DATE_ADD(CURDATE(),INTERVAL 14 DAY)),
(@pulse,1,'Investigate cold start time','Measure startup on mid-range devices and identify expensive initialization.','bug','progress','critical',@admin,@member,DATE_SUB(CURDATE(),INTERVAL 2 DAY)),
(@pulse,2,'Offline retry for drafts','Keep a draft locally when the network request fails.','feature','backlog','high',@manager,@admin,DATE_ADD(CURDATE(),INTERVAL 18 DAY)),
(@pulse,3,'Improve notification settings','Make push preferences easier to understand and change.','task','todo','medium',@member,@manager,DATE_ADD(CURDATE(),INTERVAL 8 DAY)),
(@pulse,4,'Fix clipped navigation labels','Labels are cut off on small screen sizes.','bug','review','high',@admin,@member,DATE_ADD(CURDATE(),INTERVAL 3 DAY)),
(@pulse,5,'Prepare release notes','Summarize fixes and notable changes for the next build.','task','todo','low',@manager,@admin,DATE_ADD(CURDATE(),INTERVAL 6 DAY)),
(@pulse,6,'Reduce image payload','Resize oversized assets and validate caching behavior.','task','done','medium',@admin,@member,NULL),
(@pulse,7,'Add app health event','Record failed launch events for local diagnostics.','feature','backlog','medium',@member,NULL,NULL),
(@merid,1,'Quarterly delivery overview','Create a concise overview of active work and completed milestones.','feature','progress','medium',@manager,@admin,DATE_ADD(CURDATE(),INTERVAL 9 DAY)),
(@merid,2,'Approval request gets stuck','A request can remain pending after the reviewer responds.','bug','todo','critical',@member,@manager,DATE_SUB(CURDATE(),INTERVAL 1 DAY)),
(@merid,3,'Simplify onboarding checklist','Remove duplicate steps and clarify ownership.','task','review','medium',@admin,@member,DATE_ADD(CURDATE(),INTERVAL 5 DAY)),
(@merid,4,'Archive outdated reports','Mark retired reports and remove them from default views.','task','backlog','low',@manager,@member,NULL),
(@merid,5,'Add weekly activity digest','Provide a brief in-app summary of changes across projects.','feature','backlog','medium',@admin,@manager,DATE_ADD(CURDATE(),INTERVAL 21 DAY)),
(@merid,6,'Correct timezone in exports','Exported timestamps should match the selected workspace timezone.','bug','done','high',@member,@admin,NULL),
(@atlas,6,'Improve mobile issue filters','Keep common filters visible without covering the issue list.','task','todo','medium',@manager,@member,DATE_ADD(CURDATE(),INTERVAL 10 DAY)),
(@atlas,7,'Add recent project shortcuts','Surface recently opened projects in the workspace overview.','feature','backlog','low',@admin,@manager,NULL),
(@atlas,8,'Fix comment scroll position','Return to the new comment after posting from a long issue page.','bug','progress','medium',@member,@admin,DATE_ADD(CURDATE(),INTERVAL 4 DAY)),
(@orbit,4,'Review database indexes','Inspect issue and activity queries under larger datasets.','task','progress','high',@admin,@manager,DATE_ADD(CURDATE(),INTERVAL 7 DAY)),
(@orbit,5,'Handle webhook timeout clearly','Return a useful retryable response when the downstream service times out.','bug','todo','high',@manager,@member,DATE_ADD(CURDATE(),INTERVAL 6 DAY)),
(@orbit,6,'Add API usage summary','Show daily request totals and failure rates to project managers.','feature','backlog','medium',@member,@admin,NULL)
ON DUPLICATE KEY UPDATE id=id;

INSERT INTO issue_labels(issue_id,label_id)
SELECT i.id,l.id FROM issues i JOIN labels l ON l.project_id=i.project_id
WHERE (i.project_id=@nova AND ((i.number IN (1,3,6) AND l.name='accessibility') OR (i.number IN (2,5) AND l.name='design') OR (i.number=4 AND l.name='documentation')))
   OR (i.project_id=@pulse AND ((i.number IN (1,6,7) AND l.name='performance') OR (i.number IN (2,3,4) AND l.name='android') OR (i.number=5 AND l.name='release')))
   OR (i.project_id=@merid AND ((i.number IN (1,5) AND l.name='reporting') OR (i.number IN (2,3,4,6) AND l.name='workflow') OR (i.number=2 AND l.name='urgent')))
   OR (i.project_id=@atlas AND i.number IN (6,8) AND l.name='mobile')
   OR (i.project_id=@orbit AND i.number=4 AND l.name='database')
ON DUPLICATE KEY UPDATE issue_id=issue_id;

INSERT INTO comments(issue_id,user_id,body)
SELECT i.id,@manager,'I added reproduction steps and a short acceptance checklist.' FROM issues i WHERE i.project_id=@nova AND i.number=3
AND NOT EXISTS (SELECT 1 FROM comments c WHERE c.issue_id=i.id AND c.body='I added reproduction steps and a short acceptance checklist.');
INSERT INTO comments(issue_id,user_id,body)
SELECT i.id,@member,'The contrast issue is visible in both the tooltip and its keyboard focus state.' FROM issues i WHERE i.project_id=@nova AND i.number=3
AND NOT EXISTS (SELECT 1 FROM comments c WHERE c.issue_id=i.id AND c.body='The contrast issue is visible in both the tooltip and its keyboard focus state.');
INSERT INTO comments(issue_id,user_id,body)
SELECT i.id,@admin,'Please capture a baseline measurement before changing initialization.' FROM issues i WHERE i.project_id=@pulse AND i.number=1
AND NOT EXISTS (SELECT 1 FROM comments c WHERE c.issue_id=i.id AND c.body='Please capture a baseline measurement before changing initialization.');
INSERT INTO comments(issue_id,user_id,body)
SELECT i.id,@member,'Baseline captured on the test device. Investigating image decoding next.' FROM issues i WHERE i.project_id=@pulse AND i.number=1
AND NOT EXISTS (SELECT 1 FROM comments c WHERE c.issue_id=i.id AND c.body='Baseline captured on the test device. Investigating image decoding next.');
INSERT INTO comments(issue_id,user_id,body)
SELECT i.id,@manager,'This should be included in the next release verification pass.' FROM issues i WHERE i.project_id=@pulse AND i.number=4
AND NOT EXISTS (SELECT 1 FROM comments c WHERE c.issue_id=i.id AND c.body='This should be included in the next release verification pass.');
INSERT INTO comments(issue_id,user_id,body)
SELECT i.id,@manager,'The reviewer response is saved, but the request status is not updated.' FROM issues i WHERE i.project_id=@merid AND i.number=2
AND NOT EXISTS (SELECT 1 FROM comments c WHERE c.issue_id=i.id AND c.body='The reviewer response is saved, but the request status is not updated.');
INSERT INTO comments(issue_id,user_id,body)
SELECT i.id,@admin,'I will add a query plan and index proposal to the issue.' FROM issues i WHERE i.project_id=@orbit AND i.number=4
AND NOT EXISTS (SELECT 1 FROM comments c WHERE c.issue_id=i.id AND c.body='I will add a query plan and index proposal to the issue.');

INSERT INTO activity(project_id,issue_id,user_id,action,detail)
SELECT i.project_id,i.id,i.reporter_id,'issue_created',i.title FROM issues i
WHERE i.project_id IN (@nova,@pulse,@merid) AND NOT EXISTS
(SELECT 1 FROM activity a WHERE a.issue_id=i.id AND a.action='issue_created');

INSERT INTO notifications(user_id,issue_id,message)
SELECT i.assignee_id,i.id,CONCAT('Assigned: ',p.`key`,'-',i.number,' ',i.title)
FROM issues i JOIN projects p ON p.id=i.project_id
WHERE ((i.project_id=@pulse AND i.number=1) OR (i.project_id=@merid AND i.number=2) OR (i.project_id=@nova AND i.number=3))
AND i.assignee_id IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM notifications n WHERE n.user_id=i.assignee_id AND n.issue_id=i.id AND n.message=CONCAT('Assigned: ',p.`key`,'-',i.number,' ',i.title));
