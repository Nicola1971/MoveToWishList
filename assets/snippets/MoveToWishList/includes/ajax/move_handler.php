<?php
define('MODX_API_MODE', true);
include_once("../../../../../index.php");
require_once "../functions.php";

//Language
// Sanitizzazione input e cast a string
$customLang = isset($_POST['customLang']) ? (string)$_POST['customLang'] : '';
$customLang = preg_replace('/[^a-zA-Z0-9_-]/', '', $customLang);
$customLang = basename($customLang);

// Inizializzazione array lingue
$_MTWlang = [];

// Percorso base per i file di lingua
$langBasePath = MODX_BASE_PATH . 'assets/snippets/MoveToWishList/lang/';

// Caricamento file lingua personalizzato
if ($customLang !== '' && file_exists($langBasePath . 'custom/' . $customLang . '.php')) {
    include ($langBasePath . 'custom/' . $customLang . '.php');
} else {
    // Carica sempre l'inglese come fallback
    include ($langBasePath . 'en.php');
    
    // Try manager language if different from English
    $managerLang = $modx->config['manager_language'];
    $managerLang = preg_replace('/[^a-zA-Z0-9_-]/', '', $managerLang);
    $managerLang = basename($managerLang);
    
    if ($managerLang !== 'en' && file_exists($langBasePath . $managerLang . '.php')) {
        include ($langBasePath . $managerLang . '.php');
    }
}

$evo = evolutionCMS();
$evo->db->connect();
header('Content-Type: application/json');

if (isset($_POST['move_wishlist'])) {
    try {
        $docid = (int)$_POST['docid'];
        $userId = (int)$_POST['userId'];
        $fromList = isset($_POST['from_list']) ? preg_replace('/[^a-zA-Z0-9_-]/', '', $_POST['from_list']) : '';
        $toList = isset($_POST['to_list']) ? preg_replace('/[^a-zA-Z0-9_-]/', '', $_POST['to_list']) : '';

        // Verify source TV exists
        $tvQuery = $evo->db->select('id', $evo->getFullTableName('site_tmplvars'), "name = '" . $evo->db->escape($fromList) . "'");
        if ($evo->db->getRecordCount($tvQuery) === 0) {
            echo json_encode([
                'success' => false,
                'message' => 'Invalid source TV name',
                'docid' => $docid
            ]);
            exit();
        }

        // Verify destination TV exists
        $tvQuery = $evo->db->select('id, caption', $evo->getFullTableName('site_tmplvars'), "name = '" . $evo->db->escape($toList) . "'");
        if ($evo->db->getRecordCount($tvQuery) === 0) {
            echo json_encode([
            'success' => false,
            'message' => 'Invalid destination TV name',
            'docid' => $docid
        ]);
        exit();
        }
        $tvData = $evo->db->getRow($tvQuery);
        $friendlyName = !empty($tvData['caption']) ? $tvData['caption'] : $toList;
        $tvValues = \UserManager::getValues(['id' => $userId]);
        
        // Log dei valori TV prima dell'operazione
        $modx->logEvent(1, 1, 'Current TV values:
- Source TV (' . $fromList . '): ' . (isset($tvValues[$fromList]) ? $tvValues[$fromList] : 'empty') . '
- Dest TV (' . $toList . '): ' . (isset($tvValues[$toList]) ? $tvValues[$toList] : 'empty'), 'MoveToWishList Move Handler');
        
        // Get source list items
        $sourceWishList = isset($tvValues[$fromList]) ? $tvValues[$fromList] : '';
        $sourceListIds = array_filter(array_map('trim', explode(',', $sourceWishList)));
        
        // Get destination list items
        $destWishList = isset($tvValues[$toList]) ? $tvValues[$toList] : '';
        $destListIds = array_filter(array_map('trim', explode(',', $destWishList)));

        if (in_array($docid, $sourceListIds)) {
            // Remove from source list
            $sourceListIds = array_diff($sourceListIds, [$docid]);
            $sourceWishList = implode(',', array_unique($sourceListIds));
            
            // Add to destination list
            if (!in_array($docid, $destListIds)) {
                $destListIds[] = $docid;
                $destWishList = implode(',', array_unique($destListIds));
                
                // Update both TVs
                $userData = [
                    'id' => $userId,
                    $fromList => $sourceWishList,
                    $toList => $destWishList
                ];
                \UserManager::saveValues($userData);
                
        
                echo json_encode([
                    'success' => true,
                    'docid' => $docid,
                    'message' => sprintf($_MTWlang['moved_to_wishList'], $friendlyName),
                    'source_count' => count($sourceListIds),
                    'dest_count' => count($destListIds)
                    ]);
                exit();
            } else {
                echo json_encode([
                    'success' => false,
                    'docid' => $docid,
                    'message' => sprintf($_MTWlang['already_in_destination_list'], $friendlyName)
                ]);
                exit();
            }
        } else {
            echo json_encode([
                'success' => false,
                'docid' => $docid,
                'message' => $_MTWlang['not_in_source_list']
            ]);
            exit();
        }
        
    } catch (\Exception $e) {
        echo json_encode([
            'success' => false,
            'docid' => $docid,
            'message' => $e->getMessage()
        ]);
        exit();
    }
}

// Se arriviamo qui, nessuna azione valida è stata specificata
echo json_encode([
    'success' => false,
    'message' => 'Invalid action'
]);
exit();