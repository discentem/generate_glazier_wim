package main

import (
	"bytes"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

var (
	discardMountedWim = flag.Bool("discard_wim_mount", false, "Whether or not to discard mounted wim")
	winpeBasePaths    = flag.String("winpe_base_paths", "C:\\WinPE_x86, C:\\WinPE_amd64", "Comma separate winpe base paths")
)

func ensureFolderExists(path string) error {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		e := os.MkdirAll(filepath.Dir(path), os.ModePerm)
		log.Printf("Creating %s...", path)
		if e != nil {
			return e
		}
	}

	log.Printf("%s already exists. Skipping creation...", path)
	return nil

}

func copyFileIdempotently(path, destinationPath string) {

}

func runCmd(cmdString string, params []string) (string, error) {
	cmd := exec.Command(cmdString, params...)
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		return "", err
	}
	return out.String(), nil
}

func main() {
	c, err := runCmd("python", []string{"-c", "print(\"hi\")"})
	if err != nil {
		log.Fatal(err)
	} else {
		fmt.Println(c)
	}
	err = ensureFolderExists("c:\\WinPE_x86")
	if err != nil {
		log.Fatal(err)
	}
}
