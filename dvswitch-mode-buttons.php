<?php
declare(strict_types=1);

$allowed = array('BM', 'TGIF', 'STFU', 'YSF', 'P25', 'NXDN', 'DSTAR');
if (isset($_GET['status'])) {
    $mode = '';
    $files = glob('/tmp/ABInfo_*.json');
    if (is_array($files) && count($files) > 0) {
        usort($files, static function ($a, $b) { return filemtime($b) <=> filemtime($a); });
        $data = json_decode((string)file_get_contents($files[0]), true);
        if (is_array($data)) {
            foreach (array($data['tlv']['ambe_mode'] ?? '', $data['ambe_mode'] ?? '') as $value) {
                $value = strtoupper(trim((string)$value));
                if ($value === 'YSFN' || $value === 'YSFW') { $value = 'YSF'; }
                if ($value !== '') { $mode = $value; break; }
            }
        }
    }
    $address = '';
    $ini = '/opt/MMDVM_Bridge/MMDVM_Bridge.ini';
    if (is_readable($ini)) {
        $inNetwork = false;
        foreach (file($ini, FILE_IGNORE_NEW_LINES) ?: array() as $line) {
            if (trim($line) === '[DMR Network]') { $inNetwork = true; continue; }
            if ($inNetwork && preg_match('/^\s*\[/', $line)) { break; }
            if ($inNetwork && preg_match('/^\s*Address\s*=\s*(\S+)/i', $line, $match)) { $address = $match[1]; break; }
        }
    }
    $network = (stripos($address, 'tgif') !== false) ? 'TGIF' : ((stripos($address, 'brandmeister') !== false || stripos($address, 'repeater.net') !== false) ? 'BM' : '');
    header('Content-Type: application/json');
    echo json_encode(array('ok' => $mode !== '', 'mode' => $mode, 'network' => $network));
    exit;
}
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
