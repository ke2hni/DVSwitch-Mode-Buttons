<?php
declare(strict_types=1);

$allowed = array('BM', 'TGIF', 'STFU', 'YSF', 'P25', 'NXDN', 'DSTAR');
$mode = strtoupper(trim((string)($_GET['mode'] ?? '')));
if (!in_array($mode, $allowed, true)) {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(array('ok' => false, 'error' => 'Unsupported mode'));
    exit;
}

$command = '/usr/bin/sudo /usr/local/sbin/dvswitch-mode-buttons '.escapeshellarg($mode).' 2>&1';
$output = array();
$status = 0;
exec($command, $output, $status);
header('Content-Type: application/json');
echo json_encode(array(
    'ok' => $status === 0,
    'mode' => $mode,
    'output' => implode("\n", $output),
    'status' => $status,
));
?>
