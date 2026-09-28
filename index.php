<?php
declare(strict_types=1);
require __DIR__ . '/app/bootstrap.php';

$page = (string)($_GET['page'] ?? 'dashboard');
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verify_csrf();
    require __DIR__ . '/app/actions.php';
    exit;
}
if (!in_array($page,['login','register'],true)) login_required();
require __DIR__ . '/app/views.php';
