package regression

import (
	"testing"
	testutil "tectonic/installer/tests/testutils"
	"github.com/aws/aws-sdk-go/aws"
	"reflect"
	"fmt"
	"strconv"
	"log"
)

func getParsedContract() *testutil.Contract {
	file := testutil.ReadContract()
	result := testutil.ParseContract(file)
	return result
}

func getExpectedInstanceTypes() ([]string){

	instanceType := make([]string, 0)

	result := getParsedContract()
	for index, rs := range result.Reservations {
		fmt.Printf(" Reservation Id: %s and Num Instances: %d ", rs.ReservationId, len(rs.Instances))
		for _, ins := range result.Reservations[index].Instances {
			//fmt.Printf(" - Instance Type: %s", ins.InstanceType)
			instanceType = append(instanceType, ins.InstanceType)
		}
	}
	return instanceType
}

func getActualInstanceTypes()([]string){

	instanceType := make([]string, 0)
	//call to get the EC2 AWS Instances
	resp, err := testutil.GetAwsInstances()

	if err != nil {
		fmt.Printf("there was an error listing instances in %s", err.Error())
	}

	for idx, res := range resp.Reservations {
		fmt.Printf(" Reservation Id: %s and Num Instances: %d ", *res.ReservationId, len(res.Instances))
		for _, inst := range resp.Reservations[idx].Instances {
			//fmt.Printf("    - Instance Type: %s", *inst.InstanceType)
			instanceType = append(instanceType, *inst.InstanceType)
		}
	}
	return instanceType
}

func getExpectedVolumes()([]string){

	volumes := make([]string, 0)
	result := getParsedContract()
	for index, rs := range result.Reservations {
		fmt.Printf(" Reservation Id: %s and Num Instances: %d ", rs.ReservationId, len(rs.Ebs))
		for _, ins := range result.Reservations[index].Ebs {
			volumeId := ins.VolumeId
			iops := ins.Iops
			size := ins.Size
			volumeType :=	ins.VolumeType
			volumes = append(volumes,volumeId,size,iops,volumeType)
		}
	}
	return volumes
}

func getActualVolumes()([]string){

	volumes := make([]string, 0)
	//call to get the EC2 AWS Volumes
	resp, err := testutil.GetAwsVolumes()

	if err != nil {
		log.Fatalf("there was an error listing volumes in %s", err.Error())
	}

	for _, vol := range resp.Volumes {
		volumeId := aws.StringValue(vol.VolumeId)
		size := aws.Int64Value(vol.Size)
		iops := aws.Int64Value(vol.Iops)
		volumeType := aws.StringValue(vol.VolumeType)

		volumes = append(volumes,volumeId,strconv.FormatInt(size,10),strconv.FormatInt(iops,10),volumeType)
	}

	return volumes
}


func TestAwsInstancesTypes(t *testing.T) {

	actualInstanceTypes := getActualInstanceTypes()
	expectedInstanceTypes := getExpectedInstanceTypes()

	if !reflect.DeepEqual(actualInstanceTypes, expectedInstanceTypes) {
		t.Fatalf("The Instances types actual:%s doesn't match with expected:%s",actualInstanceTypes,expectedInstanceTypes)
	}

}

func TestAwsVolumes(t *testing.T){

	actualVolumes := getActualVolumes()
	expectedVolumes := getExpectedVolumes()

	if !reflect.DeepEqual(actualVolumes, expectedVolumes) {
		t.Fatalf("The Instances types actual:%s doesn't match with expected:%s",actualVolumes,expectedVolumes)
	}
}
