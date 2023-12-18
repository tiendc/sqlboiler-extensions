[![Go Version](https://img.shields.io/badge/Go-%3E%3D%201.18-blue)](https://img.shields.io/badge/Go-%3E%3D%201.20-blue)

# SQLBoiler extensions

## Why?

[SQLBoiler](https://github.com/volatiletech/sqlboiler) generated models don't come with supports for bulk operations such as bulk insert, upsert, delete and they don't provide any mechanism to overcome the RDBMS limitations such as max number of parameters in a query or statement.

Additional functionalities:
  - modelSlice.InsertAll
  - modelSlice.InsertAllByPage (use this when len(modelSlice) is bigger than RDBMS limitation, commonly 65536 items)
  - modelSlice.UpsertAll
  - modelSlice.UpsertAllByPage
  - modelSlice.UpdateAllByPage
  - modelSlice.DeleteAll
  - modelSlice.DeleteAllByPage
  - modelSlice.GetLoaded<<FK-ref-type>> (collect all objects from model.R.<<FK-ref-type>>)
  - modelSlice.Load<<FK-ref-type>>ByPage (perform eager loading reference type by page to overcome RDBMS limitation)

Additional utility functions:
  - model.GetID() (get ID from the object)
  - modelSlice.GetIDs() (get all IDs from the list)
  - modelSlice.ToIDMap() (convert the list to a map with ID as keys and model object as values)
  - modelSlice.ToUniqueItems() (construct a slice of unique model objects from the list)
  - modelSlice.FindItemByID(id) (find item by ID from the list)
  - modelSlice.FindMissingItemIDs(checkIDs) (find missing item IDs from the list)

Supported RDBMS:
  - MySQL (well-tested)
  - Postgres (tested)
  - CockroachDB (tested)

## How-to

See the [demo](https://github.com/tiendc/sqlboiler-extensions-demo)

## Contributing

- You are welcome to make pull requests for new functions and bug fixes.

## Authors

- Dao Cong Tien ([tiendc](https://github.com/tiendc))
- Takenaka Kazumasa ([ktakenaka](https://github.com/ktakenaka))

## License

- [MIT License](LICENSE)
