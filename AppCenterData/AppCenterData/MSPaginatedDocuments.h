// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSPage.h"
#import "MSReadOptions.h"
#import "MSSerializableDocument.h"

NS_ASSUME_NONNULL_BEGIN

// A (paginated) list of documents from CosmosDB
@interface MSPaginatedDocuments : NSObject

/**
 * Initialize documents with page.
 *
 * @param page Page to instantiate documents with.
 * @param partition The partition for the documents.
 * @param documentType The type of the documents in the partition.
 * @param continuationToken The continuation token, if any.
 *
 * @return The paginated documents.
 */
- (instancetype)initWithPage:(MSPage *)page
                   partition:(NSString *)partition
                documentType:(Class)documentType
           continuationToken:(NSString *_Nullable)continuationToken; // TODO move to internal

/**
 * Initialize documents with a single page containing a document error.
 *
 * @param error Error to initialize with.
 * @param partition The partition for the documents.
 * @param documentType The type of the documents in the partition.
 *
 * @return The paginated documents.
 */
- (instancetype)initWithError:(MSDataError *)error
                    partition:(NSString *)partition
                 documentType:(Class)documentType; // TODO move to
                                                   // internal

/**
 * Boolean indicating if an extra page is available.
 *
 * @return True if there is another page of documents, false otherwise.
 */
- (BOOL)hasNextPage;

/**
 * Return the current page.
 *
 * @return The current page of documents.
 */
- (MSPage *)currentPage;

/**
 * Asynchronously fetch the next page.
 *
 * @param completionHandler Callback to accept the next page of documents.
 */
- (void)nextPageWithCompletionHandler:(void (^)(MSPage *page))completionHandler;

@end

NS_ASSUME_NONNULL_END
