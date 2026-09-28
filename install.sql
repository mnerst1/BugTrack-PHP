CREATE DATABASE IF NOT EXISTS bugtrack CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE bugtrack;

CREATE TABLE IF NOT EXISTS users (
 id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 name VARCHAR(100) NOT NULL,
 email VARCHAR(190) NOT NULL UNIQUE,
 password VARCHAR(255) NOT NULL,
 role ENUM('admin','manager','member') NOT NULL DEFAULT 'member',
 locale ENUM('en','kk','ru') NOT NULL DEFAULT 'en',
 theme ENUM('light','dark') NOT NULL DEFAULT 'light',
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS projects (
 id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 name VARCHAR(120) NOT NULL,
 `key` VARCHAR(12) NOT NULL UNIQUE,
 description TEXT NULL,
 owner_id INT UNSIGNED NOT NULL,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY (owner_id) REFERENCES users(id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS project_members (
 project_id INT UNSIGNED NOT NULL,
 user_id INT UNSIGNED NOT NULL,
 role ENUM('manager','member') NOT NULL DEFAULT 'member',
 PRIMARY KEY(project_id,user_id),
 FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS issues (
 id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 project_id INT UNSIGNED NOT NULL,
 number INT UNSIGNED NOT NULL,
 title VARCHAR(200) NOT NULL,
 description TEXT NULL,
 type ENUM('bug','task','feature') NOT NULL DEFAULT 'task',
 status ENUM('backlog','todo','progress','review','done') NOT NULL DEFAULT 'backlog',
 priority ENUM('low','medium','high','critical') NOT NULL DEFAULT 'medium',
 reporter_id INT UNSIGNED NOT NULL,
 assignee_id INT UNSIGNED NULL,
 due_date DATE NULL,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 UNIQUE KEY issue_number(project_id,number),
 INDEX issue_filters(project_id,status,priority,updated_at),
 FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
 FOREIGN KEY (reporter_id) REFERENCES users(id),
 FOREIGN KEY (assignee_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS labels (
 id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 project_id INT UNSIGNED NOT NULL,
 name VARCHAR(40) NOT NULL,
 color CHAR(7) NOT NULL DEFAULT '#5070b8',
 UNIQUE KEY project_label(project_id,name),
 FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS issue_labels (
 issue_id INT UNSIGNED NOT NULL,
 label_id INT UNSIGNED NOT NULL,
 PRIMARY KEY(issue_id,label_id),
 FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE,
 FOREIGN KEY (label_id) REFERENCES labels(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS comments (
 id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 issue_id INT UNSIGNED NOT NULL,
 user_id INT UNSIGNED NOT NULL,
 body TEXT NOT NULL,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE,
 FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS activity (
 id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 project_id INT UNSIGNED NOT NULL,
 issue_id INT UNSIGNED NULL,
 user_id INT UNSIGNED NOT NULL,
 action VARCHAR(40) NOT NULL,
 detail VARCHAR(255) NOT NULL DEFAULT '',
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 INDEX activity_project(project_id,created_at),
 FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
 FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE SET NULL,
 FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS notifications (
 id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 user_id INT UNSIGNED NOT NULL,
 issue_id INT UNSIGNED NULL,
 message VARCHAR(255) NOT NULL,
 is_read TINYINT(1) NOT NULL DEFAULT 0,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 INDEX notifications_user(user_id,is_read,created_at),
 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
 FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Demo accounts: admin@bugtrack.test, manager@bugtrack.test, member@bugtrack.test
-- Password for all three: Demo12345!  Change it after local evaluation.
INSERT INTO users(id,name,email,password,role,locale,theme) VALUES
(1,'Alex Morgan','admin@bugtrack.test','$2y$10$yl4PQEuQWtOCHNPhLCbz9uN1y9u.DZuIZX29wC2J5u8vyUdEJkL1W','admin','en','light'),
(2,'Aruzhan Sapar','manager@bugtrack.test','$2y$10$nKtRcdfkhKqbPpn9Qm/PYOhraH.qFsPFzwg.OW8bMw08RfXn0dq2.','manager','kk','light'),
(3,'Daniil Kim','member@bugtrack.test','$2y$10$oBcpYlRrhjE9me3VPdqR9O2idTTOuu0XwVapPuajlTqTcdxILEhgW','member','ru','dark');
INSERT INTO projects(id,name,`key`,description,owner_id) VALUES
(1,'Atlas Web App','ATLAS','Customer-facing product and release work.',2),
(2,'Orbit API','ORBIT','Backend services, integrations and infrastructure.',1);
INSERT INTO project_members(project_id,user_id,role) VALUES
(1,1,'manager'),(1,2,'manager'),(1,3,'member'),(2,1,'manager'),(2,2,'manager'),(2,3,'member');
INSERT INTO labels(id,project_id,name,color) VALUES
(1,1,'frontend','#5070b8'),(2,1,'accessibility','#885cc7'),(3,1,'release','#bc7841'),
(4,2,'api','#5070b8'),(5,2,'security','#c04c59');
INSERT INTO issues(id,project_id,number,title,description,type,status,priority,reporter_id,assignee_id,due_date) VALUES
(1,1,1,'Sign-in form loses error state','Validation feedback disappears after retry on mobile.','bug','progress','high',2,3,DATE_ADD(CURDATE(),INTERVAL 5 DAY)),
(2,1,2,'Keyboard navigation for project menu','Make all menu actions available with keyboard and visible focus.','task','todo','medium',2,3,DATE_ADD(CURDATE(),INTERVAL 12 DAY)),
(3,1,3,'Saved views for issue filters','Allow team members to keep frequently used filters.','feature','backlog','low',3,2,NULL),
(4,1,4,'Release checklist','Verify flows, copy and accessibility for the next release.','task','review','high',2,1,DATE_ADD(CURDATE(),INTERVAL 3 DAY)),
(5,1,5,'Fix truncated issue title','Long titles should wrap in compact layouts.','bug','done','medium',3,2,NULL),
(6,2,1,'Rate limit auth endpoint','Reduce brute force exposure while preserving usability.','task','progress','critical',1,2,DATE_ADD(CURDATE(),INTERVAL 7 DAY)),
(7,2,2,'Document webhook retries','Clarify retry timing and failure responses.','task','todo','medium',2,3,DATE_ADD(CURDATE(),INTERVAL 10 DAY)),
(8,2,3,'Add project event webhook','Send events when issues change state.','feature','backlog','medium',1,NULL,NULL);
INSERT INTO issue_labels(issue_id,label_id) VALUES (1,1),(2,2),(3,1),(4,3),(5,1),(6,5),(7,4),(8,4);
INSERT INTO comments(issue_id,user_id,body) VALUES
(1,2,'Reproduced on a narrow viewport. Please keep the error visible after submission.'),
(1,3,'I have a fix in progress and will verify both keyboard and touch flows.'),
(6,1,'Please add a short note about the chosen threshold after implementation.');
INSERT INTO activity(project_id,issue_id,user_id,action,detail) VALUES
(1,1,2,'issue_created','Sign-in form loses error state'),
(1,1,3,'status_changed','todo → progress'),
(1,4,2,'issue_created','Release checklist'),
(2,6,1,'issue_created','Rate limit auth endpoint'),
(2,6,2,'status_changed','todo → progress');
INSERT INTO notifications(user_id,issue_id,message) VALUES
(3,1,'Assigned: ATLAS-1 Sign-in form loses error state'),
(2,6,'Assigned: ORBIT-1 Rate limit auth endpoint');
