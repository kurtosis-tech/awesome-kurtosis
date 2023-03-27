# Ethereum API allows us to input "block_number-latest" to return the latest block information. Very helpful!
LATEST_BLOCK_NUMBER_GENERIC = "latest"

# We have this complex jq filter to parse a hexadecimal string with `0x` returned by the Ethereum node into an integer value
JQ_PARSE_HEX = """
def parse_hex(i):
i |
ascii_upcase 
split("") |
map({{"0": 0, "1": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9, "A": 10, "B": 11, "C": 12, "D": 13, "E": 14, "F": 15}}[.]) |
reduce .[] as $item (0; . * 16 + $item);
parse_hex({})
"""

BLOCK_NUMBER_FIELD = "block-number"
BLOCK_HASH_FIELD = "block-hash"


def get_block(plan, node_id, block_number_hex):
    """
    Returns the block information for block number `block_number_hex` (which should be a hexadecimal string starting
    with `0x`, i.e. `0x2d`)

    The object returned is a struct with 2 fields `number` (integer) and `hash` (hexadecimal string).
    """
    block_response = plan.request(
        recipe=get_block_recipe(block_number_hex),
        service_name=node_id,
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
    plan.wait(
        recipe=get_block_recipe(LATEST_BLOCK_NUMBER_GENERIC),
        field="extract." + BLOCK_NUMBER_FIELD,
        assertion=">=",
        target_value=target_block_number_hex,
        timeout="20m",  # Ethereum nodes can take a while to get in good shapes, especially at the beginning
        service_name=node_id,
    )

def get_block_recipe(block_number_hex):
    """
    Returns the recipe to run to get the block information for block number `block_number_hex` (integer)
    """
    request_body = """{{
    "method": "eth_getBlockByNumber",
    "params":[
        "{}",
        true
    ],
    "id":1,
    "jsonrpc":"2.0"
}}""".format(block_number_hex)
    return PostHttpRequestRecipe(
        port_id="rpc",
        endpoint="/",
        content_type="application/json",
        body=request_body,
        extract={
            BLOCK_NUMBER_FIELD: JQ_PARSE_HEX.format(".result.number"),
            BLOCK_HASH_FIELD: ".result.hash",
        },
    )


def extracted_field_name(field_name):
    return "extract." + field_name
