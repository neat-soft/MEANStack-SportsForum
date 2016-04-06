require("lib/backbone-graph")

class Child extends Backbone.GraphModel
  relations: [
    {
      key: "parent"
      autoCreate: true
      serializeReference: true
      type: {provider: -> Parent}
      reverseKey: "child"
    }
  ]

class Parent extends Backbone.GraphModel
  relations: [
    {
      key: "child"
      autoCreate: true
      type: {provider: -> Child}
      reverseKey: "parent"
    }
  ]

class One extends Backbone.GraphModel
  relations: [
    {
      key: "children"
      type: {provider: -> Backbone.GraphCollection}
      reverseKey: "parent"
    }
  ]

class Many extends Backbone.GraphModel
  relations: [
    {
      key: "parent"
      type: {provider: -> One}
      reverseKey: "children"
    }
  ]

class ManyMany extends Backbone.GraphModel
  relations: [
    {
      key: "many"
      type: {provider: -> Backbone.GraphCollection}
      reverseKey: "many"
    }
  ]

class Child2 extends Backbone.GraphModel
  relations: [
    {
      key: "parent"
      type: {provider: -> MoreReferencesToChild2}
      reverseKey: ["child1", "child2"]
    }
  ]

class MoreReferencesToChild2 extends Backbone.GraphModel
  relations: [
    {
      key: "child1"
      type: {provider: -> Child2}
      reverseKey: "parent"
    },
    {
      key: "child2"
      type: {provider: -> Child2}
      reverseKey: "parent"
    }
  ]

describe("Backbone Graph", ->
  describe("GraphModel", ->
    it("should have one-to-one relation", ->
      _.find([1, 3, 4], (elem)-> elem > 2)
      A = new Child()
      B = new Parent()
      A.set("parent": B)
      expect(A.get("parent")).to.equal(B)
      expect(B.get("child")).to.equal(A)
    )

    it("should be in the global store", ->
      A = new Child()
      B = new Parent()
      expect(Backbone.graphStore.models.getByCid(A.cid)).to.equal(A)
      expect(Backbone.graphStore.models.getByCid(B.cid)).to.equal(B)
    )

    it("should create store collections", ->
      A = new Child()
      B = new Parent()
      expect(Backbone.graphStore.getCollection(Child)).to.be.an.instanceof(Backbone.Collection)
      expect(Backbone.graphStore.getCollection(Parent)).to.be.an.instanceof(Backbone.Collection)
    )

    it("should create one-to-many relation by adding to parent", ->
      parent = new One()
      child = new Many()
      parent.get("children").add(child)
      expect(parent.get("children").length).to.equal(1)
      expect(parent.get("children").models[0]).to.equal(child)
      expect(child.get("parent")).to.equal(parent)
    )

    it("should create one-to-many relation by setting the child's parent", ->
      parent = new One()
      child = new Many()
      child.set("parent": parent)
      expect(parent.get("children").length).to.equal(1)
      expect(parent.get("children").models[0]).to.equal(child)
      expect(child.get("parent")).to.equal(parent)
    )

    it("should remove child from relation from parent", ->
      parent = new One()
      child = new Many()
      child.set("parent": parent)
      parent.get("children").remove(child)
      expect(child.get("parent")).to.equal(null)
    )

    it("should remove parent from relation from child", ->
      parent = new One()
      child = new Many()
      child.set("parent": parent)
      child.set("parent": null)
      expect(parent.get("children").length).to.equal(0)
    )

    it("should create many-to-many relation", ->
      part1 = new ManyMany()
      part2 = new ManyMany()
      part1.get("many").add(part2)
      expect(part2.get("many").models[0]).to.equal(part1)
    )

    it("should detach model from original relation and attach it to the new relation", ->
      parent1 = new Parent()
      child = new Child()
      parent2 = new One()
      child.set("parent": parent1)
      parent2.get("children").add(child)

      expect(child.get("parent")).to.equal(parent2)
    )

    it("should auto create model with id", ->
      child = new Child({parent: {id: "123"}})
      expect(Backbone.graphStore.models.find((m)-> m.id == "123")).to.be.an.instanceof(Parent)
    )

    it("should serialize the relation when configured to", ->
      child = new Child({parent: {id: "123"}})
      expect(child.toJSON()).to.deep.equal({parent: {id: "123"}})
    )

    it("should not serialize the relation when configured not to", ->
      parent = new Parent({child: {id: "12345"}})
      expect(parent.toJSON()).to.deep.equal({})
    )

    it("should create more one to many relations for the same type", ->
      multiple = new MoreReferencesToChild2()
      c1 = new Child2()
      c2 = new Child2()
      multiple.set("child1": c1)
      multiple.set("child2": c2)

      expect(c1.get("parent")).to.equal(multiple)
      expect(c2.get("parent")).to.equal(multiple)
    )

    it("should create one to many relation by passing the reference to the constructor", ->
      parent = new One()
      child = new Many(parent: parent)

      expect(parent.get("children").models[0]).to.equal(child)
    )
  )
)
