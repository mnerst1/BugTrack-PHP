<?php
declare(strict_types=1);

function q(string $sql, array $args = []): PDOStatement { $s = db()->prepare($sql); $s->execute($args); return $s; }
function one(string $sql, array $args = []): ?array { $v = q($sql, $args)->fetch(); return $v ?: null; }
function all(string $sql, array $args = []): array { return q($sql, $args)->fetchAll(); }
function e(?string $s): string { return htmlspecialchars((string)$s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'); }
function url(string $path = ''): string { global $config; return rtrim((string)$config['base_url'], '/') . '/' . ltrim($path, '/'); }
function redirect(string $path): never { header('Location: ' . url($path)); exit; }
function user(): ?array { static $cached = false; if ($cached !== false) return $cached; $cached = isset($_SESSION['uid']) ? one('SELECT id,name,email,role,locale,theme FROM users WHERE id=?', [(int)$_SESSION['uid']]) : null; return $cached; }
function login_required(): array { $u = user(); if (!$u) redirect('?page=login'); return $u; }
function csrf(): string { return $_SESSION['csrf'] ??= bin2hex(random_bytes(32)); }
function csrf_input(): string { return '<input type="hidden" name="csrf" value="' . e(csrf()) . '">'; }
function verify_csrf(): void { if (!hash_equals(csrf(), (string)($_POST['csrf'] ?? ''))) abort(419, 'Invalid CSRF token. Reload and retry.'); }
function abort(int $code, string $message): never { http_response_code($code); exit('<!doctype html><meta charset="utf-8"><title>Error</title><main style="font:16px system-ui;max-width:640px;margin:10vh auto"><h1>' . $code . '</h1><p>' . e($message) . '</p><a href="' . e(url('?page=dashboard')) . '">BugTrack</a></main>'); }
function flash(string $message, string $type = 'success'): void { $_SESSION['flash'] = [$message, $type]; }
function post_string(string $key, int $max = 255): string { $value=$_POST[$key] ?? ''; return is_string($value) ? mb_substr(trim($value),0,$max) : ''; }
function positive_id(mixed $value): int { $v = filter_var($value, FILTER_VALIDATE_INT); return $v && $v > 0 ? (int)$v : 0; }
function role_admin(): bool { return (user()['role'] ?? '') === 'admin'; }
function project(int $id): array { $p = one('SELECT p.*,u.name owner_name FROM projects p JOIN users u ON u.id=p.owner_id WHERE p.id=?', [$id]); if (!$p) abort(404, 'Project not found.'); return $p; }
function member(int $projectId): ?array { $u = user(); return $u ? one('SELECT * FROM project_members WHERE project_id=? AND user_id=?', [$projectId,$u['id']]) : null; }
function require_project(int $id): array { $p = project($id); if (!role_admin() && !member($id)) abort(403, 'You are not a member of this project.'); return $p; }
function can_manage(array $p): bool { $u = user(); return role_admin() || (int)$p['owner_id'] === (int)$u['id'] || (member((int)$p['id'])['role'] ?? '') === 'manager'; }
function issue(int $id): array { $i = one('SELECT i.*,p.`key` project_key,p.name project_name,p.owner_id FROM issues i JOIN projects p ON p.id=i.project_id WHERE i.id=?', [$id]); if (!$i) abort(404, 'Issue not found.'); require_project((int)$i['project_id']); return $i; }
function can_edit_issue(array $i): bool { return can_manage(['id'=>$i['project_id'],'owner_id'=>$i['owner_id']]) || (int)$i['reporter_id'] === (int)user()['id']; }
function activity(int $projectId, ?int $issueId, string $action, string $detail = ''): void { q('INSERT INTO activity(project_id,issue_id,user_id,action,detail) VALUES(?,?,?,?,?)', [$projectId,$issueId,user()['id'],$action,$detail]); }
function notify_user(?int $recipient, ?int $issueId, string $message): void { if ($recipient && $recipient !== (int)user()['id']) q('INSERT INTO notifications(user_id,issue_id,message) VALUES(?,?,?)', [$recipient,$issueId,$message]); }
function allowed(string $value, array $values, string $default): string { return in_array($value,$values,true) ? $value : $default; }
function date_or_null(string $value): ?string { if ($value === '') return null; $d = DateTimeImmutable::createFromFormat('!Y-m-d',$value); if (!$d || $d->format('Y-m-d') !== $value) abort(422,'Invalid due date.'); return $value; }
function label_ids(int $projectId): array { $ids = array_unique(array_filter(array_map('positive_id', (array)($_POST['labels'] ?? [])))); if (!$ids) return []; $placeholders = implode(',',array_fill(0,count($ids),'?')); $valid = q("SELECT id FROM labels WHERE project_id=? AND id IN ($placeholders)", array_merge([$projectId],$ids))->fetchAll(PDO::FETCH_COLUMN); if (count($valid) !== count($ids)) abort(422,'Invalid label.'); return $ids; }
function sync_labels(int $issueId, array $ids): void { q('DELETE FROM issue_labels WHERE issue_id=?',[$issueId]); foreach ($ids as $id) q('INSERT INTO issue_labels(issue_id,label_id) VALUES(?,?)',[$issueId,$id]); }
function project_users(int $projectId): array { return all('SELECT u.id,u.name,u.email,pm.role FROM project_members pm JOIN users u ON u.id=pm.user_id WHERE pm.project_id=? ORDER BY u.name',[$projectId]); }
function validate_assignee(int $projectId, int $id): ?int { if (!$id) return null; if (!one('SELECT 1 FROM project_members WHERE project_id=? AND user_id=?',[$projectId,$id])) abort(422,'Assignee must be a project member.'); return $id; }
function db_error(Throwable $e): never { error_log((string)$e); abort(500,'Database operation failed. Check the configuration and schema.'); }
