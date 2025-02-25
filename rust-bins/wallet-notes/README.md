# Libraries

The wallet libraries expose a functionality that will be needed by the wallet.
They expose an interface which takes JSON input and JSON output and it is up to
the user of the libraries to supply correct data and ensure any invariants and
preconditions that are specified.

The library currently exposes the following methods with the following
c-compatible signatures.
- Identity layer
    - `char* create_id_request_and_private_data(const char*, uint8_t*)`
    - `char* create_credential(const char*, uint8_t*)`
    - `uint8_t check_account_address_ext(const char*)`
- Regular transactions
    - `char* create_transfer_ext(const char*, uint8_t*)`
- Encrypted transactions
    - `char* create_encrypted_transfer_ext(const char*, uint8_t*)`
    - `char* combine_encrypted_amounts_ext(const char*, const char*, uint8_t*)`
    - `uint64_t decrypt_encrypted_amount_ext(const char*, uint8_t*)`
    - `char* create_pub_to_sec_transfer_ext(char*, uint8_t*)`
    - `char* create_sec_to_pub_transfer_ext(char*, uint8_t*)`
- `void free_response_string(char*)`

After calling a function that returns a `char*` value, it is the
__caller's__ responsibility to free the returned string via the
`free_response_string` function.

The functions that take an `uint8_t*` parameter will either
- successfully generate the required information (see below for the format) and
  set the `uint8_t` parameter to `1`. In this case the returned string is a JSON value.
- or fail and set the `uint8_t` parameter to `0`. In this case the returned string
  is a description of the error.

In all cases the precondition is that the input string is a NUL-terminated
UTF8-string, and the returned string is likewise a NUL-terminated UTF8-encoded string.

## create_id_request_and_private_data

Semantics: Generates an IdentityObject request, used to request an indentity to a IdentityProvider.

This function takes as input a NUL-terminated UTF8-encoded string. The string
must be a valid JSON object with fields

- `"ipInfo"` ... is a JSON object that describes the identity provider. This
  data is the one obtained from the server by making a GET request to /ip_info.

- `"arsInfos"` ... is a JSON mapping from `"arIdentity"` to `"arInfo"` where `"arInfo"` being
  a JSON object with fields `"arIdentity"`, `"arDescription"` and `"arPublicKey"`.

- `"global"` ... is a JSON object that can describes global cryptographic parameters.
   This data is obtained from the server by making a GET request to /global.

In addition the field `"arThreshold"` can be added to specify an anonymity revocation threshold different from the default value, as a JSON encoded byte value.

The output of this function is a JSON object with two keys
- "idObjectRequest" - this is the identity object request that should be sent to
  the identity provider
- "privateIdObjectData" - this is the __private__ information that the user must
  keep in order to be able to use the returned identity object.

An example of input is in the file [create_id_request_and_private_data-input.json](files/create_id_request_and_private_data-input.json).
An example of output is in the file [create_id_request_and_private_data-output.json](files/create_id_request_and_private_data-output.json).

## check_account_address

This function takes as input a NUL-terminated in utf8 encoding string and
returns a uint8.
- if the string is valid UTF8 encoding and has the correct concordium address
  format then 1 is returned
- in all other cases 0 is returned.

An example of a valid address is
`4MzQSgx2A7PwAyfu54yxZS3NjDUjX6HpisQMBJtzL7B6dbodrh`

An example of an invalid address is
`3MzQSgx2A7PwAyfu54yxZS3NjDUjX6HpisQMBJtzL7B6dbodrh`.

## create_credential

Semantics: Using the identityObject provided by the IdentityProvider, create a credential and account.

This function takes as input a NUL-terminated UTF8-encoded string. The string
must be a valid JSON object with fields

- `"ipInfo"` ... same as in the `create_id_request_and_private_data` call

- `"arsInfos"` ... same as in the `create_id_request_and_private_data` call

- `"global"` ... same as in the `create_id_request_and_private_data` call

- `"identityObject"` ... this must contain the value returned by the identity provider.

- `"privateIdObjectData"` ... this is the value that was returned by the
  `create_id_request_and_private_data` function and stored locally

- `"revealedAttributes"` ... attributes which the user wishes to reveal. This is
  an array of attribute names. The user should select these from among the
  attributes in the identityObject field. The key "revealedAttributes" is
  optional. If not present we take it as the empty set.

- `"accountNumber"` ... this must be a number between 0 and 255 (inclusive).
  Multiple credentials can be generated from the same identity object, and this
  number is essentially a nonce. It __must__ be different for different
  credentials from the same id object, otherwise the credential will not be
  accepted by the chain.

The returned value is a JSON object with the following fields.

- `"credential"` - this is the credential that is to be deployed on the chain. All
  data here is public.

- `"credentialData"` - contains the public and __private__ keys of the account the
  credential belongs to. This is very sensitive and must be kept protected.

- `"accountAddress"` - the address of the account this credential belongs to. This
  will either be a new account or existing account, depending on the input "accountData".

- `"encryptionPublicKey"` - the account public key for encrypted transfers.

- `"encryptionSecretKey"` - the account private key for encrypted transfers.

An example input to this request is in the file [create_credential-input.json](files/create_credential-input.json).
An example output to this request is in the file [create_credential-output.json](files/create_credential-output.json).

## create_transfer_ext

Semantics: Creates a transfer transaction with the provided values.

This function takes as input a NUL-terminated UTF8-encoded string. The string
must be a valid JSON object with fields

- `"from"` ... address of the sender account.

- `"to"` ... address of the receiver account.

- `"expiry"` ... unix timestamp of the expiry date of the transaction.

- `"nonce"` ... nonce of the sender account.

- `"keys"` ... mapping with the keys of the sender account.

- `"energy"` ... max energy wanted for the transfer.

- `"amount"` ... string containing the amount wanted to be transferred.

The returned value is a JSON object with the following fields:

- `"signatures"` ... list with signatures of the transaction with the provided keys.

- `"transaction"` ... the serialized transaction that can be sent to the chain.

An example input to this request is in the file [create_transfer-input.json](files/create_transfer-input.json).
An example output to this request is in the file [create_transfer-output.json](files/create_transfer-output.json).

## create_configure_delegation_transaction

Semantics: Creates a `configure delegation`-transaction with the provided values.

This function takes as input a NUL-terminated UTF8-encoded string. The string
must be a valid JSON object with fields

- `"from"` ... address of the sender account.

- `"expiry"` ... unix timestamp of the expiry date of the transaction.

- `"nonce"` ... nonce of the sender account.

- `"keys"` ... mapping with the keys of the sender account.

- `"energy"` ... max energy wanted for the transfer.

The following fields are optional:

- `"capital"` ... string containing the amount to be staked.

- `"restakeEarnings"` ... bool indicating whether earnings should be restaked.

- `"delegationTarget"` ... JSON indicating either delegation to the L-pool or to a baker pool.

The delegation target should either be of the form
```json
{
    "type": "delegateToLPool"
}
```
or

```json
{
    "type": "delegateToBaker",
    "targetBaker": 100
}
```
where `100` should be replaced with relevant baker id.

To add a delegator, all of the optional fields must be present. For an existing delegator the fields that are present will be updated on chain. A delegator is removed if the `capital` is set to `"0"`.

The returned value is a JSON object with the following fields:

- `"signatures"` ... list with signatures of the transaction with the provided keys.

- `"transaction"` ... the serialized transaction that can be sent to the chain.

Example input to this request are in the files [create_configure_delegation_transacion-input.json](files/create_configure_delegation_transacion-input.json) and [2-create_configure_delegation_transacion-input.json](2-files/create_configure_delegation_transacion-input.json).
Example output to this request are in the files [2-files/create_configure_delegation_transacion-output.json](files/create_configure_delegation_transacion-output.json).

## create_configure_baker_transaction

Semantics: Creates a transfer transaction with the provided values.

This function takes as input a NUL-terminated UTF8-encoded string. The string
must be a valid JSON object with fields

- `"from"` ... address of the sender account.

- `"expiry"` ... unix timestamp of the expiry date of the transaction.

- `"nonce"` ... nonce of the sender account.

- `"keys"` ... mapping with the keys of the sender account.

- `"energy"` ... max energy wanted for the transfer.

The following fields are optional:

- `"capital"` ... string containing the amount to be staked.

- `"restakeEarnings"` ... bool indicating whether earnings should be restaked.

- `"metadataUrl"` ... string containing a metadata URL. Max size is 2048 bytes.

- `"openStatus"` ... whether the pool is closed, open for delegation or closed for new delegators.
  This is indicated with one of the strings `"openForAll"`, `"closedForNew"`, or `"closedForAll"`.

- `"transactionFeeCommission"` ... number indicating the transaction fee commission in parts per hundred thousand.

- `"bakingRewardCommission"` ... number indicating the baking reward commission in parts per hundred thousand.

- `"finalizationRewardCommission"` ... number indicating the finalization reward commission in parts per hundred thousand.

- `"bakerKeys"` ... the baker keys. These are generated using the function `generate_baker_keys` documented below.

To add a baker, all of the optional fields must be present. For an existing baker the fields that are present will be updated on chain. A baker is removed if the `capital` is set to `"0"`.

The returned value is a JSON object with the following fields:

- `"signatures"` ... list with signatures of the transaction with the provided keys.

- `"transaction"` ... the serialized transaction that can be sent to the chain.

An example input to this request is in the file [create_configure_baker-transaction-input.json](files/create_configure_baker-transaction-input.json).
An example output to this request is in the file [create_configure_baker-transaction-output.json](files/create_configure_baker-transaction-output.json).

## generate_baker_keys

Semantics: Generates baker keys.

This functiones takes no input. An output of the function could look like
```json
{
    "electionVerifyKey": "7c6804c3a3460c0a90a4d7bf6e2787c70a32a8d35faf8725862d73172f1c5383",
    "electionPrivateKey": "69e736da67e493bc1a781d835f6877e4aa2102fe4c118de9d4435b6a4b5cba4a",
    "signatureVerifyKey": "c1a11131f42df6328a8e111524b1e45c9b537c8f60d442540d8001756c82c20b",
    "signatureSignKey": "44da32121d641e0e1be49900164a5c6eca2a594f1676cb7d744b171e74676b18",
    "aggregationVerifyKey": "922668fdbdcf66a1dec7d5d284e9c3dba2f4fc10856face74db06189691e9609b5cc78fc77398af7bae2f2ee6e0361f1057e2627f1988d15bb16a6096382a1220f8e8c820e1a38df0c6357b6639241ea97e12c4f33365241b7186a98d6161b85",
    "aggregationSignKey": "48a3748a9ecf98fbccac29b7ccd0e1074f2bca73655154242c3c2835945601e9"
}
```

Note: In order for a node to use the baker credentials to bake, the field `"bakerId"` with the ID of the baker needs to be added to the above JSON.

## create_encrypted_transfer_ext

Semantics: Create an encrypted transfer transaction with the provided values.

This function takes as input a NUL-terminated UTF8-encoded string. The string
must be a valid JSON object with fields

- `"from"` ... address of the sender account.

- `"to"` ... address of the receiver account.

- `"expiry"` ... unix timestamp of the expiry date of the transaction.

- `"nonce"` ... nonce of the sender account.

- `"keys"` ... mapping with the keys of the sender account.

- `"energy"` ... max energy wanted for the transfer.

- `"amount"` ... string containing the amount wanted to be transferred.

- `"global"` ... same as in the `create_id_request_and_private_data` call

- `"senderSecretKey"` ... the secret key of the sender account.

- `"receiverPublicKey"` ... the private key of the receiver account.

- `"inputEncryptedAmount"` ... the encrypted amount generated when transferring an amount to the shielded balance
  or directly received from another account in another transfer. It must be a JSON object with the fields:
      - `"aggEncryptedAmount"` ... the ciphered amount
      - `"aggAmount"` ... the amount on plaintext
      - `"aggIndex"` ... the index up to which the encrypted amounts on the account have been combined.

The returned value is a JSON object with the following fields:

- `"signatures"` ... list with signatures of the transaction with the provided keys.

- `"transaction"` ... the serialized transaction that can be sent to the chain.

- `"remaining"` ... the remaining encrypted balance.

An example input to this request is in the file [create_encrypted_transfer-input.json](files/create_encrypted_transfer-input.json).
An example output to this request is in the file [create_encrypted_transfer-output.json](files/create_encrypted_transfer-output.json).

## combine_encrypted_amounts_ext

Semantics: Sums two encrypted amounts.

This function takes as input two NUL-terminated UTF8-encoded strings. The inputted strings must be
ciphertexts of encrypted amounts. The function will return a NUL-terminated UTF8-encoded string
containing the sum of both encrypted amounts.

For example, if using encrypted amounts that expect to be decrypted with the key:
```
a820662531d0aac70b3a80dd8a249aa692436097d06da005aec7c56aad17997ec8331d1e4050fd8dced2b92f06277bd51008c7a9b2805954be902db14e6aec6643fadf88398490bd67ec8df6c1c72e3f
```
, combining `Encrypted(1000000)`:

```
800e19f1086f51d62788bb64a6624596c017a40e66bce195d1bee963a2d09f68301d1372d41dffda4ac89a41536919d890b357021e6889fd0fdb1f1754d4f552194912262794a50ef7c63cd4478b9bb6247f80c9a40023b620e2d763a68026ed88c2a0834fa2471560800234093b74164ea30f46fe05c53e6fbb356902b21e23e21d07d21c854488082ea8b493cdbfd6a4674fed444ebd7213bc56f9e8fa6edef22fb38039d477cb239a8041e6957ad68c86be179c335c1771f2741edf141002
```
and `Encrypted(2000000)`:
```
94a011e5597bf35d161d837c1798b3fea7dba281c23d764706a26e3a510cff2d82784fdc13455650f67f5a4bba1fc92089cd754c9520a56ab6da2b520691d167a89f6c422ed44d68c8a3c93e0589d80a3ee84df78a207311ff0b9477f87b10b9aaacb8f1a1028d19ba37a6e0a9ccfe47dae2f0aaed79b9fa23eb9108bc19fb0cf8e8e9efa1c50521233f2e3c5b041577a3421353c2d8a042b792bc0f147746a28f4da28ad17e7f4d9e140af82384edfaa2d11c2a1fe1301da450be23c04b3ffa
```
would output `Encrypted(3000000)`:
```
8280233813ce7c0c6f7a4e152928e31e51b1b0ad2e0cef2a3d75a7366ed93eaa77a0c5b20634a6b7e3f3133c8c65e1838023aaa7be1913eac2efc8985f73fd435f3081a3ded830c0c047fef53427229dba644363513ad0af7538c3e97b3d4fe985ccf96b79633e3844601320b82ede794915510a2f1c522e57590c2d13ab966a1fbc3603fe79c33efa90312ea0f863b7999fb67c0d088e059bda4ae692c9022fd2f0d0844ba83e8f70f0a535c953eba7cc86b6f431e3c8aa9f4429014c86b7d2
```

## decrypt_encrypted_amount_ext

Semantics: Decrypts an encrypted amount.

This function takes as input a NUL-terminated UTF8-encoded string. The string
must be a valid JSON object with fields

- `"encryptedAmount"` ... the ciphertext of an encrypted amount.

- `"encryptionSecretKey"` ... the secret key of the owner of the amount.

The output will show the decrypted amount.

An example input to this request is in the file [decrypt_encrypted_amount-input.json](files/decrypt_encrypted_amount-input.json).
An example output to this request is in the file [decrypt_encrypted_amount-output.json](files/decrypt_encrypted_amount-output.json).

## create_pub_to_sec_transfer_ext

Semantics: Creates a transaction that transfers an amount from the public balance to the shielded balance of an account.

This function takes as input a NUL-terminated UTF8-encoded string. The string
must be a valid JSON object with fields

- `"from"` ... address of the sender account.

- `"expiry"` ... unix timestamp of the expiry date of the transaction.

- `"nonce"` ... nonce of the sender account.

- `"keys"` ... mapping with the keys of the sender account.

- `"energy"` ... max energy wanted for the transfer.

- `"amount"` ... string containing the amount wanted to be transferred.

- `"global"` ... same as in the `create_id_request_and_private_data` call

The returned value is a JSON object with the following fields:

- `"signatures"` ... list with signatures of the transaction with the provided keys.

- `"transaction"` ... the serialized transaction that can be sent to the chain.
- `"addedSelfEncryptedAmount"` ... encryption of the amount wanted to be transferred.

An example input to this request is in the file [create_pub_to_sec_transfer-input.json](files/create_pub_to_sec_transfer-input.json).
An example output to this request is in the file [create_pub_to_sec_transfer-output.json](files/create_pub_to_sec_transfer-output.json).

## create_sec_to_pub_transfer_ext

Semantics: Creates a transaction that transfers an amount from the shielded balance to the public balance of an account.

This function takes as input a NUL-terminated UTF8-encoded string. The string
must be a valid JSON object with fields

- `"from"` ... address of the sender account.

- `"expiry"` ... unix timestamp of the expiry date of the transaction.

- `"nonce"` ... nonce of the sender account.

- `"keys"` ... mapping with the keys of the sender account.

- `"energy"` ... max energy wanted for the transfer.

- `"amount"` ... string containing the amount wanted to be transferred.

- `"global"` ... same as in the `create_id_request_and_private_data` call

- `"senderSecretKey"` ... the secret key of the sender account.

- `"inputEncryptedAmount"` ... the encrypted amount generated when transferring an amount to the shielded balance
  or directly received from another account in another transfer. It must be a JSON object with the fields:
      - `"aggEncryptedAmount"` ... the ciphered amount
      - `"aggAmount"` ... the amount on plaintext
      - `"aggIndex"` ... the index up to which the encrypted amounts on the account have been combined.

The returned value is a JSON object with the following fields:

- `"signatures"` ... list with signatures of the transaction with the provided keys.

- `"transaction"` ... the serialized transaction that can be sent to the chain.

- `"remaining"` ... the remaining encrypted balance.

An example input to this request is in the file [create_sec_to_pub-input.json](files/create_sec_to_pub-input.json).
An example output to this request is in the file [create_sec_to_pub-output.json](files/create_sec_to_pub-output.json).

## generate_accounts_ext

Semantics: Given an identity object, generate all the possible accounts, with their encryption keys, that could have been created from it.

This function takes as input a NUL-terminated UTF8-encoded string. The string msut be a valid JSON object with fields

- `"global"`, the cryptographic parameters
- `"identityObject"`, the identity object, as received from the identity provider.
- `"privateIdObjectData"`, the private identity object data, as used in the `create_credential` call.
- (optional) `"start"`, an unsigned integer <= 255 that indicates which accounts it should generate.

The return value is a a JSON array with JSON objects as entries. Each object has fields
- `"accountAddress"`
- `"encryptionSecretKey"`
- `"encryptionPublicKey"`

With meaning that can be discerned from their names.

## Example
The [Example C program](example.c) that uses the library is available. This
program reads a JSON file and passes it to the library, retrieving and printing
the result. On a linux system the program can be compiled and run like so.
  - First compile the libraries in [../mobile_wallet](../mobile-wallet) by running
    ```cargo build --release```.
  - Next from this directory run
    ```gcc example.c -lmobile_wallet -L ../../mobile_wallet/target/release/ -o example```
    or
    ```clang example.c -lmobile_wallet -L ../../mobile_wallet/target/release/ -o example```
    depending on what C compiler is preffered.

The binary can then be run with the following inputs:
- `LD_LIBRARY_PATH=../../mobile_wallet/target/release ./example create_transfer-input.json`:
   calls `create_transfer` with the contents of `create_transfer-input.json`.

- `LD_LIBRARY_PATH=../../mobile_wallet/target/release ./example create_id_request_and_private_data-input.json`:
   calls `create_id_request_and_private_data` with the contents of `create_id_request_and_private_data-input.json`.

- `LD_LIBRARY_PATH=../../mobile_wallet/target/release ./example create_credential-input.json`:
   calls `create_credential` with the contents of `create_credential-input.json`.

- `LD_LIBRARY_PATH=../../mobile_wallet/target/release ./example create_encrypted_transfer-input.json`:
   calls `create_encrypted_transfer` with with the contents of `create_encrypted_transfer-input.json`.

- `LD_LIBRARY_PATH=../../mobile_wallet/target/release ./example combine-amounts <encryptedAmount1> <encryptedAmount2>`:
   calls `combine_encrypted_amounts` with the two amounts.

- `LD_LIBRARY_PATH=../../mobile_wallet/target/release ./example decrypt_encrypted_amount-input.json`:
   calls `decrypt_encrypted_amount` with the contents of `decrypt_encrypted_amount-input.json`.

- `LD_LIBRARY_PATH=../../mobile_wallet/target/release ./example create_sec_to_pub-input.json`:
   calls `create_sec_to_pub` with the contents of `create_sec_to_pub-input.json`.

- `LD_LIBRARY_PATH=../../mobile_wallet/target/release ./example create_pub_to_sec-input.json`:
   calls `create_pub_to_sec` with the contents of `create_pub_to_sec-input.json`.

- `LD_LIBRARY_PATH=../../mobile_wallet/target/release ./example check-address <address>`:
   calls `check_account_address` with the given address.

# Example JSON input/output files mapping.

|                                      | input                                                                                                  | output                                                                                                   |
|--------------------------------------|--------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|
| `create_id_request_and_private_data` | [`create_id_request_and_private_data-input.json`](files/create_id_request_and_private_data-input.json) | [`create_id_request_and_private_data-output.json`](files/create_id_request_and_private_data-output.json) |
| `create_configure_baker_transaction` | [`create_configure_baker_transaction-input.json`](files/create_configure_baker_transaction-input.json) | [`create_configure_baker_transaction-output.json`](files/create_configure_baker_transaction-output.json) |
| `create_configure_delegation_transaction` | [`create_configure_delegation_transaction-input.json`](files/create_configure_delegation_transaction-input.json) | [`create_configure_delegation_transaction-output.json`](files/create_configure_delegation_transaction-output.json) |
| `create_credential`                  | [`create_credential-input.json`](files/create_credential-input.json)                                   | [`create_credential-output.json`](files/create_credential-output.json)                                   |
| `create_transfer_ext`                | [`create_transfer-input.json`](files/create_transfer-input.json)                                       | [`create_transfer-output.json`](files/create_transfer-output.json)                                       |
| `create_encrypted_transfer_ext`      | [`create_encrypted_transfer-input.json`](files/create_encrypted_transfer-input.json)                   | [`create_encrypted_transfer-output.json`](files/create_encrypted_transfer-output.json)                   |
| `decrypt_encrypted_amount_ext`       | [`decrypt_encrypted_amount-input.json`](files/decrypt_encrypted_amount-input.json)                     | [`decrypt_encrypted_amount-output.json`](files/decrypt_encrypted_amount-output.json)                     |
| `create_sec_to_pub_ext`              | [`create_sec_to_pub-input.json`](files/create_sec_to_pub-input.json)                                   | [`create_sec_to_pub-output.json`](files/create_sec_to_pub-output.json)                                   |
| `create_pub_to_sec_ext`              | [`create_pub_to_sec-input.json`](files/create_pub_to_sec-input.json)                                   | [`create_pub_to_sec-output.json`](files/create_pub_to_sec-output.json)                                   |
| `generate_accounts_ext`               | [generate-accounts-input.json](files/generate-accounts-input.json) |  [generate-accounts-output.json](files/generate-accounts-output.json) |


# Other change set from the previous version

1. All Amounts are now expected to be strings in JSON. The wallet-proxy will
   serve amounts in this format, and the library will expect them.
2. All Wallet-proxy endpoints are now versioned, concretely this means that they
   are renamed from `/X` to `/v0/X`
3. The `create_id_request_and_private_data` now expects an additional field
   `arsInfos` in the input. This field is obtained in the same way as `ipInfo`,
   via the `GET /v0/ip_info` call.
4. The `create_credential` call has an equivalent change.
5. The `create_transfer`, `create_encrypted_transfer`, `create_pub_to_sec` and `create_sec_to_pub` calls have an additional parameter "energy". This can be
   obtained via a GET request to `/v0/transactionCost?type="simpleTransfer"` or replacing `simpleTransfer` with `encryptedTransfer`, `transferToSecret` or `transferToPublic`.
6. The identity object response will now be wrapped into a version object, i.e.,
   it is of the form
```json
{
  "v": 0,
  "value": {...}
}
```
where {...} is the response as it used to be.
