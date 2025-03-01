import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:xs/src/pages/bangumi_detail/controller.dart';
import 'package:xs/src/pages/bangumi_detail/models/bangumi_detail_model.dart';
import 'package:xs/src/utils/time.dart';
import 'package:xs/src/widgets/keepalive.dart';
import 'package:xs/src/widgets/subordinate_scroll_controller.dart';

class BangumiDetailEpisodesView extends StatelessWidget {
  const BangumiDetailEpisodesView({super.key, this.active = false, this.data});
  final bool active;
  final BangumiDetailModel? data;

  @override
  Widget build(BuildContext context) {
    const String assetName = 'assets/images/no_image.svg';
    final Widget noImage = SvgPicture.asset(assetName);
    Brightness currentBrightness = MediaQuery.of(context).platformBrightness;
    // 设置状态栏图标的亮度
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: currentBrightness == Brightness.light
          ? Brightness.dark
          : Brightness.light,
    ));
    return GetBuilder(
        id: Get.currentRoute,
        global: false,
        init: BangumiDetailEpisodesController(),
        builder: (controller) {
          return SafeArea(
            top: false,
            bottom: false,
            maintainBottomViewPadding: true,
            child: Builder(builder: (context) {
              final parentController = PrimaryScrollController.of(context);
              final scrollController =
                  SubordinateScrollController(parentController);
              return KeepAliveWrapper(
                  child: NotificationListener<ScrollEndNotification>(
                onNotification: (notification) {
                  final metrics = notification.metrics;
                  if (metrics.atEdge) {
                    bool isTop = metrics.pixels == 0;
                    if (isTop) {
                    } else {
                      // if (controller.isLoading.isFalse) {
                      //   controller.more();
                      // }
                    }
                  }
                  return false;
                },
                child: RefreshIndicator(
                  displacement: 60,
                  edgeOffset: 80,
                  onRefresh: () async {
                    await controller.reload();
                  },
                  child: controller.obx((state) {
                    return CustomScrollView(
                      key: const PageStorageKey('bangumi-detail-episodes'),
                      controller:
                          active ? scrollController : ScrollController(),
                      shrinkWrap: true,
                      slivers: [
                        SliverOverlapInjector(
                            handle:
                                NestedScrollView.sliverOverlapAbsorberHandleFor(
                                    context)),
                        SliverPadding(
                          padding: const EdgeInsets.only(
                              top: 10, left: 10, right: 10, bottom: 10),
                          sliver: SliverGrid.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 200,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 1.2),
                              itemCount: state!.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () {
                                    Get.toNamed('/vod/${Get.arguments.id}',
                                        arguments: {
                                          'id': Get.arguments.id,
                                          'episode': state[index].sort,
                                          'data': data,
                                          'episodes': state
                                        });
                                    // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    //   behavior: SnackBarBehavior.floating,
                                    //   margin: const EdgeInsets.only(
                                    //       bottom: 10, left: 100, right: 100),
                                    //   content: Text(state[index].title),
                                    // ));
                                  },
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: Padding(
                                      padding: const EdgeInsets.all(0.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(7),
                                                  color: Colors.grey
                                                      .withOpacity(0.1)),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(7),
                                                child: Stack(
                                                  alignment:
                                                      AlignmentDirectional
                                                          .bottomCenter,
                                                  // fit: StackFit.expand,
                                                  children: [
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(7),
                                                      ),
                                                      child: state[index]
                                                              .image
                                                              .isNotEmpty
                                                          ? Image.network(
                                                              state[index]
                                                                  .image,
                                                              width: double
                                                                  .infinity,
                                                              height: double
                                                                  .infinity,
                                                              fit: BoxFit.cover,
                                                              errorBuilder:
                                                                  (context,
                                                                      error,
                                                                      stackTrace) {
                                                                return noImage;
                                                              },
                                                            )
                                                          : noImage,
                                                    ),
                                                    Positioned(
                                                      bottom: 5,
                                                      right: 0,
                                                      child: Row(
                                                        children: [
                                                          Visibility(
                                                            visible: true,
                                                            maintainSize: false,
                                                            maintainSemantics:
                                                                false,
                                                            maintainAnimation:
                                                                false,
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      top: 1,
                                                                      left: 5,
                                                                      right: 5,
                                                                      bottom:
                                                                          3),
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      right: 5),
                                                              decoration: BoxDecoration(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              5),
                                                                  color: Colors
                                                                      .black
                                                                      .withAlpha(
                                                                          120)),
                                                              child: Text(
                                                                state[index]
                                                                        .status
                                                                    ? '有资源'
                                                                    : '无资源',
                                                                style: const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        12),
                                                              ),
                                                            ),
                                                          ),
                                                          Visibility(
                                                            visible: state[
                                                                        index]
                                                                    .duration >
                                                                0,
                                                            maintainSize: false,
                                                            maintainSemantics:
                                                                false,
                                                            maintainAnimation:
                                                                false,
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      top: 1,
                                                                      left: 5,
                                                                      right: 5,
                                                                      bottom:
                                                                          3),
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      right: 5),
                                                              decoration: BoxDecoration(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              5),
                                                                  color: Colors
                                                                      .black
                                                                      .withAlpha(
                                                                          120)),
                                                              child: Text(
                                                                Duration(
                                                                        seconds:
                                                                            state[index].duration)
                                                                    .toString()
                                                                    .split('.')
                                                                    .first,
                                                                style: const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        12),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        onTap: () {
                                                          Get.toNamed(
                                                              '/vod/${Get.arguments.id}',
                                                              arguments: {
                                                                'id': Get
                                                                    .arguments
                                                                    .id,
                                                                'episode':
                                                                    state[index]
                                                                        .sort,
                                                                'data': data,
                                                                'episodes':
                                                                    state
                                                              });
                                                          // ScaffoldMessenger.of(context)
                                                          //     .showSnackBar(SnackBar(
                                                          //   behavior:
                                                          //       SnackBarBehavior.floating,
                                                          //   margin: const EdgeInsets.only(
                                                          //       bottom: 10,
                                                          //       left: 100,
                                                          //       right: 100),
                                                          //   content:
                                                          //       Text(state[index].title),
                                                          // ));
                                                          // Get.toNamed('/thread/${state[index].id}',
                                                          //     arguments: state[index]);
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            height: 2,
                                          ),
                                          Text(
                                            '第${state[index].sort}集 ${state[index].title}',
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                const TextStyle(fontSize: 15),
                                          ),
                                          Opacity(
                                            opacity: 0.7,
                                            child: Text(
                                              Time.dateTimeFormat(
                                                  state[index].airdate.toInt()),
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                        ),
                      ],
                    );
                  }),
                ),
              ));
            }),
          );
        });
  }
}
