extends GdUnitTestSuite
## Scanning 200 fake cars must take less than 300 ms (budget from Etapa 01,
## with margin for slow CI machines).

const CAR_COUNT: int = 200
const BUDGET_MS: float = 300.0


func after_test() -> void:
	clean_temp_dir()


func test_scan_200_cars_under_budget() -> void:
	var root: String = create_temp_dir("perf_packs")
	var files: Dictionary = {}
	for i: int in CAR_COUNT:
		var slug: String = "carro_%03d" % i
		files["cars/%s/car.json" % slug] = TestContent.car_dict("perf", slug)
	TestContent.write_pack(root.path_join("perf"), TestContent.pack_dict("perf"), files)

	var library: ContentLibrary = ContentLibrary.new()
	var options: ContentScanOptions = TestContent.options_for(root)
	var started: int = Time.get_ticks_usec()
	var report: ContentReport = library.scan(options)
	var elapsed_ms: float = (Time.get_ticks_usec() - started) / 1000.0

	assert_bool(report.is_empty()).override_failure_message(report.to_text()).is_true()
	assert_int(library.list_cars().size()).is_equal(CAR_COUNT)
	assert_float(elapsed_ms).override_failure_message("scan levou %.1f ms" % elapsed_ms).is_less(
		BUDGET_MS
	)
	prints("Varredura de %d carros: %.1f ms" % [CAR_COUNT, elapsed_ms])
