.PHONY: pb
pb:
	protoc --go_out=. payloads/*.proto
