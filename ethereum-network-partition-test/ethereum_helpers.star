# Ethereum API allows us to input "block_number-latest" to return the latest block information. Very helpful!
LATEST_BLOCK_NUMBER_GENERIC = "latest"

# We have this complex jq filter to remove the `0x` prefix on the hex string returned by the Ethereum node
# and pad the hexadecimal string to 20 characters (which should be a limit we hopefully never hit)
# This is a hack to get the hexadecimal block numbers to be comparable between each other
# We have the equivalent function in Starlark below (see `pad`)
HEX_PAD_NUMBER = 20
HEX_PAD_NUMBER_FOR_JQ = HEX_PAD_NUMBER + 2  # +2 to account for the additional `0x` at the beginning of the hex string
JQ_PAD_HEX_FILTER = """def pad(i): (({0} - (i | length)) * "0") + (i | sub("0x"; "")); pad({1})"""

BLOCK_NUMBER_FIELD = "block-number"
BLOCK_HASH_FIELD = "block-hash"


def get_block(plan, node_id, block_number_hex):
    """
    Returns the block information for block number `block_number_hex` (which should be a hexadecimal string starting
    with `0x`, i.e. `0x2d`)

    The object returned is a struct with 2 fields `number` and `hash`, both hexadecimal encoded strings.
    """
    block_response = plan.request(
        recipe=get_block_recipe(node_id, block_number_hex),
    )
    return struct(
        number=block_response[extracted_field_name(BLOCK_NUMBER_FIELD)],
        hash=block_response[extracted_field_name(BLOCK_HASH_FIELD)],
    )


def wait_until_node_reached_block(plan, node_id, target_block_number_hex):
    """
    This function blocks until the node `node_id` has reached block number `target_block_number_hex`.

    If node has already produced this block, it returns immediately.
    """
    block_number_response = plan.wait(
        recipe=get_block_recipe(node_id, LATEST_BLOCK_NUMBER_GENERIC),
        field="extract." + BLOCK_NUMBER_FIELD,
        assertion=">=",
        target_value=pad(target_block_number_hex),
        timeout="20m",  # Ethereum nodes can take a while to get in good shapes, especially at the beginning
    )
    return block_number_response[extracted_field_name(BLOCK_NUMBER_FIELD)]


def get_block_recipe(node_id, block_number_hex):
    """
    Returns the recipe to run to get the block information for block number `block_number_hex` (which should be a
    hexadecimal string starting with `0x`, i.e. `0x2d`)
    """
    request_body = """{
    "method": "eth_getBlockByNumber",
    "params":[
        \"""" + block_number_hex + """\",
        true
    ],
    "id":1,
    "jsonrpc":"2.0"
}"""
    return struct(
        service_id=node_id,
        port_id="rpc",
        endpoint="/",
        method="POST",
        content_type="application/json",
        body=request_body,
        extract={
            BLOCK_NUMBER_FIELD: JQ_PAD_HEX_FILTER.format(HEX_PAD_NUMBER_FOR_JQ, ".result.number"),
            BLOCK_HASH_FIELD: ".result.hash",
        },
    )


def pad(hex):
    """
    Removes the `0x` prefix and pads the hexadecimal string with zeros to reach a HEX_PAD_NUMBER character long string
    As explained above for JQ_PAD_HEX_FILTER, this is to make hexadecimal numbers comparable
    """
    res = ""
    hex_no_prefix = hex.replace("0x", "")
    for _ in range(0, HEX_PAD_NUMBER - len(hex_no_prefix)):
        res += "0"
    return res + hex_no_prefix


def extracted_field_name(field_name):
    return "extract." + field_name
