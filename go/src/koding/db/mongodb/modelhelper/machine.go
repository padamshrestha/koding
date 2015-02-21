package modelhelper

import (
	"koding/db/models"

	"labix.org/v2/mgo"
	"labix.org/v2/mgo/bson"
)

type Bongo struct {
	ConstructorName string `json:"constructorName"`
	InstanceId      string `json:"instanceId"`
}

type MachineContainer struct {
	Bongo Bongo           `json:"bongo_"`
	Data  *models.Machine `json:"data"`
	*models.Machine
}

var (
	MachineColl            = "jMachines"
	MachineConstructorName = "JMachine"
)

func GetMachines(userId bson.ObjectId) ([]*MachineContainer, error) {
	machines := []*models.Machine{}

	query := func(c *mgo.Collection) error {
		return c.Find(bson.M{"users.id": userId}).All(&machines)
	}

	err := Mongo.Run(MachineColl, query)
	if err != nil {
		return nil, err
	}

	containers := []*MachineContainer{}

	for _, machine := range machines {
		bongo := Bongo{
			ConstructorName: MachineConstructorName,
			InstanceId:      "1", // TODO: what should go here?
		}
		container := &MachineContainer{bongo, machine, machine}

		containers = append(containers, container)
	}

	return containers, nil
}

var (
	MachineStateRunning = "Running"
)

func GetRunningVms() ([]models.Machine, error) {
	query := bson.M{"status.state": MachineStateRunning}
	return findMachine(query)
}

func GetMachinesByUsername(username string) ([]models.Machine, error) {
	user, err := GetUser(username)
	if err != nil {
		return nil, err
	}

	return GetOwnMachines(user.ObjectId)
}

func GetOwnMachines(userId bson.ObjectId) ([]models.Machine, error) {
	query := bson.M{"users.id": userId, "users.owner": true}
	return findMachine(query)
}

func GetSharedMachines(userId bson.ObjectId) ([]models.Machine, error) {
	query := bson.M{"users.id": userId, "users.permanent": true}
	return findMachine(query)
}

func GetCollabMachines(userId bson.ObjectId) ([]models.Machine, error) {
	query := bson.M{"users.id": userId, "users.permanent": false}
	return findMachine(query)
}

func findMachine(query bson.M) ([]models.Machine, error) {
	machines := []models.Machine{}

	queryFn := func(c *mgo.Collection) error {
		iter := c.Find(query).Iter()

		var machine models.Machine
		for iter.Next(&machine) {
			machines = append(machines, machine)
		}

		return iter.Close()
	}

	if err := Mongo.Run(MachineColl, queryFn); err != nil {
		return nil, err
	}

	return machines, nil
}

func UpdateMachineAlwaysOn(machineId bson.ObjectId, alwaysOn bool) error {
	query := func(c *mgo.Collection) error {
		return c.Update(
			bson.M{"_id": machineId},
			bson.M{"$set": bson.M{"meta.alwaysOn": alwaysOn}},
		)
	}

	return Mongo.Run(MachineColl, query)
}

func CreateMachine(m *models.Machine) error {
	query := func(c *mgo.Collection) error {
		return c.Insert(m)
	}

	return Mongo.Run(MachineColl, query)
}
