// Reads operator ECDSA and BLS private keys and computes required public keys to register with BLSCompendium
// This reads the input file ../script/input/5/playground_avs_input.json and writes back the modified file
package main

import (
	"crypto/ecdsa"

	"github.com/Layr-Labs/eigenlayer-AVS-playgrounds/crypto/bls"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"

	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
)

type BN254G1Element struct {
	X string `json:"X"`
	Y string `json:"Y"`
}

type BN254G2Element struct {
	X0 string `json:"X0"`
	Y0 string `json:"Y0"`
	X1 string `json:"X1"`
	Y1 string `json:"Y1"`
}

type Operator struct {
	ECDSAPrivateKey                string         `json:"ECDSAPrivateKey"`
	BN254PrivateKey                string         `json:"BN254PrivateKey"`
	BN254G1PublicKey               BN254G1Element `json:"BN254G1PublicKey"`
	BN254G2PublicKey               BN254G2Element `json:"BN254G2PublicKey"`
	SchnorrSignatureOfECDSAAddress string         `json:"SchnorrSignatureOfECDSAAddress"`
	SchnorrSignatureR              BN254G1Element `json:"SchnorrSignatureR"`
}

type PlaygroundAVSInput struct {
	Operators                    []Operator `json:"operators"`
	StakerPrivateKeys            []string   `json:"stakerPrivateKeys"`
	Stake                        [][]int    `json:"stake"`
	IndicesOfstakersToBeUnstaked []int      `json:"indicesOfstakersToBeUnstaked"`
}

// TODO: read these as CLI flags instead of hardcoding here
const PLAYGROUND_AVS_INPUT_FILE_PATH = "../script/input/5/playground_avs_input.json"

func main() {

	PLAYGROUND_AVS_INPUT_ABSOLUTE_FILE_PATH, err := filepath.Abs(PLAYGROUND_AVS_INPUT_FILE_PATH)
	if err != nil {
		panic(err)
	}

	var playgroundAVSInput PlaygroundAVSInput
	parseAVSInputFile(PLAYGROUND_AVS_INPUT_ABSOLUTE_FILE_PATH, &playgroundAVSInput)

	fillOperatorKeysInfo(&playgroundAVSInput)

	writeBackModifiedAVSInputFile(PLAYGROUND_AVS_INPUT_ABSOLUTE_FILE_PATH, &playgroundAVSInput)

	fmt.Println(PLAYGROUND_AVS_INPUT_ABSOLUTE_FILE_PATH, "updated successfully")

}

func fillOperatorKeysInfo(playgroundAVSInput *PlaygroundAVSInput) {
	for i := 0; i < len(playgroundAVSInput.Operators); i++ {
		// note that bls is the signature scheme, which we are using on the BN254 curve
		blsKeyPair, err := bls.BlsKeysFromString(playgroundAVSInput.Operators[i].BN254PrivateKey)
		if err != nil {
			panic(err)
		}
		fmt.Println("Read operator", i, "BN254 private key:", playgroundAVSInput.Operators[i].BN254PrivateKey)
		// Fill in the Public keys from the private key
		playgroundAVSInput.Operators[i].BN254G1PublicKey.X = blsKeyPair.PublicKey.X.String()
		playgroundAVSInput.Operators[i].BN254G1PublicKey.Y = blsKeyPair.PublicKey.Y.String()
		fmt.Printf("Generated BN254 G1 public key: (%s %s)\n", blsKeyPair.PublicKey.X.String(), blsKeyPair.PublicKey.Y.String())

		playgroundAVSInput.Operators[i].BN254G2PublicKey.X0 = blsKeyPair.GetPubKeyPointG2().X.A0.String()
		playgroundAVSInput.Operators[i].BN254G2PublicKey.X1 = blsKeyPair.GetPubKeyPointG2().X.A1.String()
		playgroundAVSInput.Operators[i].BN254G2PublicKey.Y0 = blsKeyPair.GetPubKeyPointG2().Y.A0.String()
		playgroundAVSInput.Operators[i].BN254G2PublicKey.Y1 = blsKeyPair.GetPubKeyPointG2().Y.A1.String()
		fmt.Printf("Generated BN254 G2 public key: (%s %s, %s %s)\n", blsKeyPair.GetPubKeyPointG2().X.A0.String(), blsKeyPair.GetPubKeyPointG2().X.A1.String(), blsKeyPair.GetPubKeyPointG2().Y.A0.String(), blsKeyPair.GetPubKeyPointG2().Y.A1.String())

		// blsKeyPair.MakeRegistrationData()
		operatorAddr := getAddressFromPrivateKey(playgroundAVSInput.Operators[i].ECDSAPrivateKey)
		s, R, _ := blsKeyPair.MakeRegistrationData(operatorAddr)
		playgroundAVSInput.Operators[i].SchnorrSignatureOfECDSAAddress = s.String()
		fmt.Printf("Generated Schnorr signature of ECDSA address: %s\n", s.String())
		playgroundAVSInput.Operators[i].SchnorrSignatureR.X = R.X.String()
		playgroundAVSInput.Operators[i].SchnorrSignatureR.Y = R.Y.String()
		fmt.Printf("Generated Schnorr signature R: (%s %s)\n\n", R.X.String(), R.Y.String())
	}
}

func getAddressFromPrivateKey(privateKeyStr string) common.Address {
	if privateKeyStr[:2] == "0x" {
		privateKeyStr = privateKeyStr[2:]
	}

	privateKey, err := crypto.HexToECDSA(privateKeyStr)
	if err != nil {
		log.Fatal(err)
	}
	publicKey := privateKey.Public()
	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		log.Fatal("error casting public key to ECDSA")
	}
	operatorAddr := crypto.PubkeyToAddress(*publicKeyECDSA)
	return operatorAddr
}

func parseAVSInputFile(playgroundAVSInputFilePath string, playgroundAVSInput *PlaygroundAVSInput) {
	file, err := os.Open(playgroundAVSInputFilePath)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	byteValue, _ := ioutil.ReadAll(file)
	json.Unmarshal(byteValue, &playgroundAVSInput)
}

func writeBackModifiedAVSInputFile(playgroundAVSInputFilePath string, playgroundAVSInput *PlaygroundAVSInput) {
	// Marshal the modified data
	modifiedData, err := json.MarshalIndent(playgroundAVSInput, "", "  ")
	if err != nil {
		log.Fatal(err)
	}

	// Write the modified data back to the file
	err = ioutil.WriteFile(playgroundAVSInputFilePath, modifiedData, 0644)
	if err != nil {
		log.Fatal(err)
	}
}
