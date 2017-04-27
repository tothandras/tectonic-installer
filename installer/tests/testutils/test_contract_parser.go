package testutils

import (
	"fmt"
	"encoding/json"
	"io/ioutil"
)

type Contract struct {
	Reservations []struct {
		ReservationId string			`json:"ReservationId"`
		Instances []struct {
			InstanceId   string		`json:"InstanceId"`
			InstanceType string		`json:"InstanceType"`
			ImageId      string		`json:"ImageId"`
			State struct {
				Code int		`json:"Code"`
				Name string		`json:"Name"`
			}
		}
		Ebs []struct {
			VolumeId   string		`json:"VolumeId"`
			Size	string			`json:"Size"`
			Iops	string			`json:"Iops"`
			VolumeType string		`json:"VolumeType"`
		}
		Placement struct {
			AvailabilityZone string		`json:"AvailabilityZone"`
		}
	}
}

func ReadContract() []byte {
	file, err := ioutil.ReadFile("../testutils/test_contract.json")
	if err != nil {
		fmt.Printf("// error while reading file %s\n", file)
		fmt.Printf("File error: %v\n", err)
		panic(err)
	}
	return file
}

func ParseContract(file []byte) (*Contract){

	var res Contract
	err := json.Unmarshal([]byte(file), &res)
	if err != nil {
		panic(err)
	}
	return &res
}


