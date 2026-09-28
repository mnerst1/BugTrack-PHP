<?php
declare(strict_types=1);
$action = (string)($_POST['action'] ?? '');
if ($action === 'register') {
    $name=post_string('name',100); $email=strtolower(post_string('email',190)); $pass=(string)($_POST['password'] ?? '');
    if (mb_strlen($name)<2 || !filter_var($email,FILTER_VALIDATE_EMAIL) || strlen($pass)<10) { flash('Use a valid name, email and a password of at least 10 characters.','error'); redirect('?page=register'); }
    if (one('SELECT id FROM users WHERE email=?',[$email])) { flash('Email already registered.','error'); redirect('?page=register'); }
    q('INSERT INTO users(name,email,password) VALUES(?,?,?)',[$name,$email,password_hash($pass,PASSWORD_DEFAULT)]);
    session_regenerate_id(true); $_SESSION['uid']=(int)db()->lastInsertId(); redirect('?page=dashboard');
}
if ($action === 'login') {
    $email=strtolower(post_string('email',190)); $pass=(string)($_POST['password'] ?? '');
    $account=one('SELECT id,password FROM users WHERE email=?',[$email]);
    if (!$account || !password_verify($pass,$account['password'])) { flash('Invalid email or password.','error'); redirect('?page=login'); }
    session_regenerate_id(true); $_SESSION['uid']=(int)$account['id']; redirect('?page=dashboard');
}
if ($action === 'logout') { $_SESSION=[]; session_destroy(); redirect('?page=login'); }
$u=login_required();
if ($action === 'theme_toggle') {
    $theme=$u['theme']==='dark' ? 'light' : 'dark';
    q('UPDATE users SET theme=? WHERE id=?',[$theme,$u['id']]);
    if (isset($_POST['ajax'])) { header('Content-Type: application/json'); echo json_encode(['ok'=>true,'theme'=>$theme]); exit; }
    $back=(string)($_POST['back'] ?? '?page=dashboard');
    redirect(str_starts_with($back,'?') ? $back : '?page=dashboard');
}
if ($action === 'profile') {
    $name=post_string('name',100); $email=strtolower(post_string('email',190));
    if (mb_strlen($name)<2 || !filter_var($email,FILTER_VALIDATE_EMAIL)) abort(422,'Invalid name or email.');
    if (one('SELECT id FROM users WHERE email=? AND id<>?',[$email,$u['id']])) abort(422,'Email already registered.');
    $locale=allowed(post_string('locale'),['en','kk','ru'],'en'); $theme=allowed(post_string('theme'),['light','dark'],'light');
    $old=(string)($_POST['current_password'] ?? ''); $new=(string)($_POST['new_password'] ?? '');
    if ($old!=='' || $new!=='') {
        $hash=one('SELECT password FROM users WHERE id=?',[$u['id']])['password'];
        if (!password_verify($old,$hash) || strlen($new)<10) abort(422,'Current password incorrect or new password too short.');
    }
    q('UPDATE users SET name=?,email=?,locale=?,theme=? WHERE id=?',[$name,$email,$locale,$theme,$u['id']]);
    if ($new!=='') q('UPDATE users SET password=? WHERE id=?',[password_hash($new,PASSWORD_DEFAULT),$u['id']]);
    flash('Profile saved.'); redirect('?page=profile');
}
if ($action === 'project_create') {
    if ($u['role']==='member') abort(403,'Only managers and admins can create projects.');
    $name=post_string('name',120); $key=strtoupper(post_string('key',12)); $desc=post_string('description',10000);
    if (mb_strlen($name)<3 || !preg_match('/^[A-Z][A-Z0-9]{1,11}$/',$key)) abort(422,'Invalid project name or key.');
    try {
        db()->beginTransaction(); q('INSERT INTO projects(name,`key`,description,owner_id) VALUES(?,?,?,?)',[$name,$key,$desc,$u['id']]); $id=(int)db()->lastInsertId();
        q('INSERT INTO project_members(project_id,user_id,role) VALUES(?,?,?)',[$id,$u['id'],'manager']); activity($id,null,'project_created',$name); db()->commit();
    } catch (Throwable $e) { if (db()->inTransaction()) db()->rollBack(); db_error($e); }
    redirect('?page=project&id='.$id);
}
if (str_starts_with($action,'project_') || in_array($action,['member_add','member_remove','label_add','label_remove'],true)) {
    $pid=positive_id($_POST['project_id'] ?? 0); $p=require_project($pid); if (!can_manage($p)) abort(403,'Manager access required.');
    if ($action==='project_update') {
        $name=post_string('name',120); if (mb_strlen($name)<3) abort(422,'Project name too short.');
        q('UPDATE projects SET name=?,description=? WHERE id=?',[$name,post_string('description',10000),$pid]); activity($pid,null,'project_updated',$name);
    } elseif ($action==='project_delete') {
        if (!role_admin() && (int)$p['owner_id'] !== (int)$u['id']) abort(403,'Only owner or admin can delete this project.');
        q('DELETE FROM projects WHERE id=?',[$pid]); redirect('?page=projects');
    } elseif ($action==='member_add') {
        $email=strtolower(post_string('email',190)); $target=one('SELECT id,name FROM users WHERE email=?',[$email]); if (!$target) abort(422,'Registered user not found.');
        $role=allowed(post_string('role'),['manager','member'],'member');
        q('INSERT INTO project_members(project_id,user_id,role) VALUES(?,?,?) ON DUPLICATE KEY UPDATE role=VALUES(role)',[$pid,$target['id'],$role]);
        activity($pid,null,'member_added',$target['name']); notify_user((int)$target['id'],null,'You were added to '.$p['name']);
    } elseif ($action==='member_remove') {
        $targetId=positive_id($_POST['user_id'] ?? 0); if ($targetId===(int)$p['owner_id']) abort(422,'Cannot remove project owner.');
        q('DELETE FROM project_members WHERE project_id=? AND user_id=?',[$pid,$targetId]); activity($pid,null,'member_removed',(string)$targetId);
    } elseif ($action==='label_add') {
        $name=post_string('name',40); $color=post_string('color',7); if ($name==='' || !preg_match('/^#[0-9a-fA-F]{6}$/',$color)) abort(422,'Invalid label.');
        q('INSERT INTO labels(project_id,name,color) VALUES(?,?,?)',[$pid,$name,$color]); activity($pid,null,'label_added',$name);
    } elseif ($action==='label_remove') {
        q('DELETE FROM labels WHERE project_id=? AND id=?',[$pid,positive_id($_POST['label_id'] ?? 0)]);
    } else abort(404,'Unknown action.');
    flash('Saved.'); redirect('?page=project&id='.$pid);
}
if ($action==='issue_create' || $action==='issue_update') {
    $existing=$action==='issue_update' ? issue(positive_id($_POST['issue_id'] ?? 0)) : null;
    $pid=$existing ? (int)$existing['project_id'] : positive_id($_POST['project_id'] ?? 0); $p=require_project($pid);
    if ($existing && !can_edit_issue($existing)) abort(403,'Cannot edit this issue.');
    $title=post_string('title',200); if (mb_strlen($title)<3) abort(422,'Title too short.');
    $desc=post_string('description',30000);
    $type=allowed(post_string('type'),['bug','task','feature'],'task'); $status=allowed(post_string('status'),['backlog','todo','progress','review','done'],'backlog');
    $priority=allowed(post_string('priority'),['low','medium','high','critical'],'medium');
    $assignee=validate_assignee($pid,positive_id($_POST['assignee_id'] ?? 0)); $due=date_or_null(post_string('due_date',10)); $labels=label_ids($pid);
    try {
        db()->beginTransaction();
        if ($existing) {
            q('UPDATE issues SET title=?,description=?,type=?,status=?,priority=?,assignee_id=?,due_date=? WHERE id=?',[$title,$desc,$type,$status,$priority,$assignee,$due,$existing['id']]);
            $id=(int)$existing['id']; activity($pid,$id,'issue_updated',$title);
            if ($existing['status']!==$status) activity($pid,$id,'status_changed',$existing['status'].' → '.$status);
            if ((int)$existing['assignee_id'] !== (int)$assignee) notify_user($assignee,$id,'Assigned: '.$p['key'].'-'.$existing['number'].' '.$title);
        } else {
            q('SELECT id FROM projects WHERE id=? FOR UPDATE',[$pid]);
            $number=(int)one('SELECT COALESCE(MAX(number),0)+1 n FROM issues WHERE project_id=?',[$pid])['n'];
            q('INSERT INTO issues(project_id,number,title,description,type,status,priority,reporter_id,assignee_id,due_date) VALUES(?,?,?,?,?,?,?,?,?,?)',[$pid,$number,$title,$desc,$type,$status,$priority,$u['id'],$assignee,$due]);
            $id=(int)db()->lastInsertId(); activity($pid,$id,'issue_created',$title); notify_user($assignee,$id,'Assigned: '.$p['key'].'-'.$number.' '.$title);
        }
        sync_labels($id,$labels); db()->commit();
    } catch (Throwable $e) { if (db()->inTransaction()) db()->rollBack(); db_error($e); }
    redirect('?page=issue&id='.$id);
}
if ($action==='issue_delete' || $action==='issue_status' || $action==='comment_add') {
    $i=issue(positive_id($_POST['issue_id'] ?? 0));
    if ($action==='issue_delete') {
        if (!can_edit_issue($i)) abort(403,'Cannot delete this issue.');
        activity((int)$i['project_id'],(int)$i['id'],'issue_deleted',$i['title']); q('DELETE FROM issues WHERE id=?',[$i['id']]); redirect('?page=project&id='.$i['project_id']);
    }
    if ($action==='issue_status') {
        $status=allowed(post_string('status'),['backlog','todo','progress','review','done'],''); if ($status==='') abort(422,'Invalid status.');
        q('UPDATE issues SET status=? WHERE id=?',[$status,$i['id']]); activity((int)$i['project_id'],(int)$i['id'],'status_changed',$i['status'].' → '.$status);
        notify_user((int)$i['assignee_id'],(int)$i['id'],'Status changed: '.$i['project_key'].'-'.$i['number'].' → '.$status);
        if (isset($_POST['ajax'])) { header('Content-Type: application/json'); echo json_encode(['ok'=>true]); exit; }
        redirect('?page=issue&id='.$i['id']);
    }
    $body=post_string('body',5000); if ($body==='') abort(422,'Comment cannot be empty.');
    q('INSERT INTO comments(issue_id,user_id,body) VALUES(?,?,?)',[$i['id'],$u['id'],$body]); activity((int)$i['project_id'],(int)$i['id'],'comment_added',mb_substr($body,0,100));
    notify_user((int)$i['reporter_id'],(int)$i['id'],'New comment on '.$i['project_key'].'-'.$i['number']); notify_user((int)$i['assignee_id'],(int)$i['id'],'New comment on '.$i['project_key'].'-'.$i['number']);
    redirect('?page=issue&id='.$i['id']);
}
if ($action==='comment_update' || $action==='comment_delete') {
    $comment=one('SELECT c.*,i.project_id FROM comments c JOIN issues i ON i.id=c.issue_id WHERE c.id=?',[positive_id($_POST['comment_id'] ?? 0)]);
    if (!$comment) abort(404,'Comment not found.');
    issue((int)$comment['issue_id']);
    if ((int)$comment['user_id'] !== (int)$u['id'] && !can_manage(project((int)$comment['project_id']))) abort(403,'Cannot change this comment.');
    if ($action==='comment_delete') {
        q('DELETE FROM comments WHERE id=?',[$comment['id']]);
        activity((int)$comment['project_id'],(int)$comment['issue_id'],'comment_deleted','');
    } else {
        $body=post_string('body',5000); if ($body==='') abort(422,'Comment cannot be empty.');
        q('UPDATE comments SET body=? WHERE id=?',[$body,$comment['id']]);
        activity((int)$comment['project_id'],(int)$comment['issue_id'],'comment_updated',mb_substr($body,0,100));
    }
    redirect('?page=issue&id='.$comment['issue_id'].'#comments');
}
if ($action==='notification_read') {
    $id=positive_id($_POST['notification_id'] ?? 0);
    if ($id) q('UPDATE notifications SET is_read=1 WHERE id=? AND user_id=?',[$id,$u['id']]);
    else q('UPDATE notifications SET is_read=1 WHERE user_id=?',[$u['id']]);
    redirect('?page=notifications');
}
abort(404,'Unknown action.');
