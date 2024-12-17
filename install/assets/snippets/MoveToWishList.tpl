<?php
/**
 * MoveToWishList
 * 
 * Addon for UserWishList to move items between multiple wishlists
 *
 * @category    snippet
 * @version     1.0.0
 * @author      Nicola Lambathakis http://www.tattoocms.it/
 * @internal    @modx_category UserWishList
 * @lastupdate  17-12-2024 16:45
 * @internal    @installset base
 */

if (!defined('MODX_BASE_PATH')) {
    die('What are you doing? Get out of here!');
}

// Parameters per le classi e testi
$btnClass = isset($btnClass) ? $btnClass : '';
$btnText = isset($btnText) ? $btnText : '';
$selectClass = isset($selectClass) ? $selectClass : '';
$wrapperClass = isset($wrapperClass) ? $wrapperClass : '';

// Template hardcoded
const BUTTON_TPL = '@CODE:<button type="button" class="wishlist-move-btn [+btn_class+]" onclick="moveToWishlist([+docid+], \'[+current_list+]\', \'[+destination_list+]\')">[+button_text+]</button>';
const OPTION_TPL = '@CODE:<option value="[+destination_list+]">[+list_name+]</option>';
const SELECT_TPL = '@CODE:<div class="wishlist-move-wrapper [+wrapper_class+]">
    <select class="wishlist-move-select [+select_class+]" onchange="if(this.value) moveToWishlist([+docid+], \'[+current_list+]\', this.value)">
        <option value="">[+select_label+]</option>
        [+options+]
    </select>
</div>';

// Required parameters
$current = isset($current) ? $current : '';
if (empty($current)) {
    $modx->logEvent(1, 1, 'Current wishlist not specified (parameter: current)', 'MoveToWishList');
    return 'Current wishlist not specified (parameter: current)';
}

// Optional parameters with defaults
$tpl = isset($tpl) ? $tpl : $buttonTpl;
$tplWrapper = isset($tplWrapper) ? $tplWrapper : $selectTpl;
$docid = isset($item_id) ? (int)$item_id : 0;
if ($docid === 0) {
    $modx->logEvent(1, 1, 'Item ID not specified (parameter: item_id)', 'MoveToWishList');
    return 'Item ID not specified';
}
$customLang = isset($customLang) ? $customLang : '';

// Parametri per le notifiche Toast
$toastClose = isset($toastClose) ? $toastClose : 'true';
$toastErrorBg = isset($toastErrorBg) ? $toastErrorBg : 'linear-gradient(to right, #ff5f6d, #ffc371)';
$toastErrorGrav = isset($toastErrorGrav) ? $toastErrorGrav : 'top';
$toastErrorPos = isset($toastErrorPos) ? $toastErrorPos : 'center';
$toastErrorDur = isset($toastErrorDur) ? $toastErrorDur : '3000';

$toastSuccessBg = isset($toastSuccessBg) ? $toastSuccessBg : 'linear-gradient(to right, #00b09b, #96c93d)';
$toastSuccessGrav = isset($toastSuccessGrav) ? $toastSuccessGrav : 'top';
$toastSuccessPos = isset($toastSuccessPos) ? $toastSuccessPos : 'center';
$toastSuccessDur = isset($toastSuccessDur) ? $toastSuccessDur : '3000';

// Get destination lists
$moveToLists = isset($moveToLists) ? $moveToLists : '';
$moveToLists = array_filter(array_map('trim', explode(',', $moveToLists)));

if (empty($moveToLists)) {
    $modx->logEvent(1, 1, 'No destination wishlist specified (parameter: moveToLists)', 'MoveToWishList');
    return 'No destination wishlist specified (parameter: moveToLists)';
}

// Get friendly names from TV captions
$friendlyNames = [];
foreach ($moveToLists as $listName) {
    $tvQuery = $modx->db->select('caption', $modx->getFullTableName('site_tmplvars'), "name = '" . $modx->db->escape($listName) . "'");
    if ($modx->db->getRecordCount($tvQuery) > 0) {
        $tvData = $modx->db->getRow($tvQuery);
        $friendlyNames[$listName] = !empty($tvData['caption']) ? $tvData['caption'] : $listName;
    } else {
        $friendlyNames[$listName] = $listName;
    }
}

// Include language file
$_MTWlang = [];
$langPath = MODX_BASE_PATH . 'assets/snippets/MoveToWishList/lang/';

// Try custom language
if (!empty($customLang) && file_exists($langPath . 'custom/' . $customLang . '.php')) {
    include($langPath . 'custom/' . $customLang . '.php');
} else {
    // Load default English
    include($langPath . 'en.php');
    
    // Try manager language if different from English
    $managerLang = $modx->config['manager_language'];
    if ($managerLang !== 'en' && file_exists($langPath . $managerLang . '.php')) {
        include($langPath . $managerLang . '.php');
    }
}

// Add required JavaScript
$modx->regClientStartupHTMLBlock('
<script>
document.addEventListener("DOMContentLoaded", function() {
    if (typeof jQuery === "undefined") {
        console.error("jQuery not loaded");
        return;
    }
    window.moveToWishlist = function(docid, fromList, toList) {
        $.ajax({
            url: "' . MODX_SITE_URL . 'assets/snippets/MoveToWishList/includes/ajax/move_handler.php",
            type: "POST",
            data: {
                move_wishlist: 1,
                docid: docid,
                userId: "' . $_SESSION['webInternalKey'] . '",
                from_list: fromList,
                to_list: toList,
                customLang: "' . $customLang . '"
            },
            success: function(response) {
                if (response.success) {
                    Toastify({
                        text: response.message,
                        duration: ' . $toastSuccessDur . ',
                        close: ' . $toastClose . ',
                        gravity: "' . $toastSuccessGrav . '",
                        position: "' . $toastSuccessPos . '",
                        style: {
                            background: "' . $toastSuccessBg . '"
                        }
                    }).showToast();
                    
                    // Aggiorniamo entrambi i contatori
                    if (response.source_count !== undefined) {
                        // Aggiorna il badge nel counter
                        $(".wishlist-counter .badge").text(response.source_count);
                        
                        // Aggiorna tutti gli elementi che mostrano il totale items
                        $("[data-wishlist-total]").text(response.source_count);
                    }
                    
                    let $item = $("#wishlist-item-" + docid);
                    if ($item.length) {
                        $item.fadeOut(400, function() {
                            $(this).remove();
                            if ($(".wishlist-item").length === 0) {
                                location.reload();
                            }
                        });
                    } else {
                        console.error("Element not found:", "#wishlist-item-" + docid);
                        location.reload();
                    }
                } else {
                    Toastify({
                        text: response.message,
                        duration: ' . $toastErrorDur . ',
                        close: ' . $toastClose . ',
                        gravity: "' . $toastErrorGrav . '",
                        position: "' . $toastErrorPos . '",
                        style: {
                            background: "' . $toastErrorBg . '"
                        }
                    }).showToast();
                }
            },
            error: function(xhr, status, error) {
                console.error("Ajax error:", {xhr, status, error});
                Toastify({
                    text: ' . json_encode($_MTWlang['ajax_error']) . ',
                    duration: ' . $toastErrorDur . ',
                    close: ' . $toastClose . ',
                    gravity: "' . $toastErrorGrav . '",
                    position: "' . $toastErrorPos . '",
                    style: {
                        background: "' . $toastErrorBg . '"
                    }
                }).showToast();
            }
        });
    };
});
</script>
');

// Prepare output based on number of destination lists
$output = '';
if (count($moveToLists) === 1) {
    $destList = $moveToLists[0];
    
    // Prepara il testo del bottone
    if (!empty($btnText)) {
        // Sostituisci il placeholder con il nome amichevole della lista
        $buttonText = str_replace('[+destination_name+]', $friendlyNames[$destList], $btnText);
        // Nel caso il placeholder non sia presente, aggiungiamo il nome alla fine
        if ($buttonText === $btnText) {
            $buttonText .= ' ' . $friendlyNames[$destList];
        }
    } else {
        // Usa il testo dal file di lingua
        $buttonText = sprintf($_MTWlang['move_to_list'], $friendlyNames[$destList]);
    }

    $fields = array(
        'docid' => $docid,
        'current_list' => $current,
        'destination_list' => $destList,
        'button_text' => $buttonText,
        'btn_class' => $btnClass
    );
    
    $output = $modx->parseChunk(BUTTON_TPL, $fields, '[+', '+]');
} else {
    // Multiple destinations - use select template
    $options = '';
    foreach ($moveToLists as $list) {
        $optionFields = array(
            'docid' => $docid,
            'current_list' => $current,
            'destination_list' => $list,
            'list_name' => $friendlyNames[$list]
        );
        $options .= $modx->parseChunk(OPTION_TPL, $optionFields, '[+', '+]');
    }
    
    $fields = array(
        'docid' => $docid,
        'current_list' => $current,
        'options' => $options,
        'select_label' => $_MTWlang['select_destination'],
        'select_class' => $selectClass,
        'wrapper_class' => $wrapperClass
    );
    
    $output = $modx->parseChunk(SELECT_TPL, $fields, '[+', '+]');
}

return $output;